const {onDocumentCreated, onDocumentUpdated} = require('firebase-functions/v2/firestore');
const {onObjectFinalized} = require('firebase-functions/v2/storage');
const admin = require('firebase-admin');

admin.initializeApp();

// Firestore 인스턴스 (eastapp-dev 데이터베이스 사용)
const db = admin.firestore();
db.settings({databaseId: 'eastapp-dev'});

const ROAD_IMAGE_CACHE_CONTROL = 'public, max-age=31536000, immutable';
const ROAD_IMAGE_PATH_HINTS = [
  'road_conditions/',
  'road_condition/',
  'road-surface/',
  'road_surface/',
];

function isRoadConditionImagePath(name) {
  if (!name) return false;
  const lower = name.toLowerCase();
  return ROAD_IMAGE_PATH_HINTS.some((hint) => lower.includes(hint));
}

// =============================================================================
// 공지사항 생성 시 모든 사용자에게 알림
// =============================================================================
exports.onAnnouncementCreated = onDocumentCreated(
  {
    document: 'announcements/{announcementId}',
    database: 'eastapp-dev',
  },
  async (event) => {
    const announcement = event.data.data();
    const announcementId = event.params.announcementId;

    console.log(`공지사항 생성: ${announcement.title}`);

    try {
      // 1. 공지사항 알림을 허용한 사용자 조회
      const usersSnapshot = await db.collection('users').get();

      // 2. FCM 토큰 수집 + 토큰-사용자 매핑
      const tokens = [];
      const tokenToUserRefs = new Map();
      usersSnapshot.forEach((doc) => {
        const user = doc.data();
        const fcmToken = user.fcmToken;
        const notificationSettings = user.notificationSettings || {};

        // 전체 알림 + 공지사항 알림이 모두 활성화된 경우만
        if (
          fcmToken &&
          notificationSettings.enabled === true &&
          notificationSettings.announcements === true
        ) {
          tokens.push(fcmToken);
          if (!tokenToUserRefs.has(fcmToken)) {
            tokenToUserRefs.set(fcmToken, []);
          }
          tokenToUserRefs.get(fcmToken).push(doc.ref);
        }
      });

      if (tokens.length === 0) {
        console.log('알림을 받을 사용자가 없습니다');
        return null;
      }

      console.log(`${tokens.length}명에게 알림 전송 예정`);

      // 3. 500개 이하 청크로 분할 전송
      const CHUNK_SIZE = 500;
      let totalSuccessCount = 0;
      let totalFailureCount = 0;
      const failedTokens = [];
      const invalidTokens = new Set();

      for (let i = 0; i < tokens.length; i += CHUNK_SIZE) {
        const chunkTokens = tokens.slice(i, i + CHUNK_SIZE);
        const chunkNumber = Math.floor(i / CHUNK_SIZE) + 1;
        const totalChunks = Math.ceil(tokens.length / CHUNK_SIZE);

        const message = {
          notification: {
            title: '새로운 공지사항',
            body: announcement.title,
          },
          data: {
            type: 'announcement',
            announcementId: announcementId, // 딥링크용 ID
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
          },
          tokens: chunkTokens,
        };

        try {
          const response = await admin.messaging().sendEachForMulticast(message);
          totalSuccessCount += response.successCount;
          totalFailureCount += response.failureCount;

          console.log(
            `[공지 푸시][청크 ${chunkNumber}/${totalChunks}] 성공: ${response.successCount}개, 실패: ${response.failureCount}개`
          );

          response.responses.forEach((resp, idx) => {
            if (resp.success) return;

            const failedToken = chunkTokens[idx];
            failedTokens.push(failedToken);

            const errorCode = resp.error && resp.error.code;
            console.error(
              `[공지 푸시][청크 ${chunkNumber}] 토큰 실패: ${failedToken}, 에러코드: ${errorCode}`
            );

            if (
              errorCode === 'messaging/registration-token-not-registered' ||
              errorCode === 'messaging/invalid-registration-token'
            ) {
              invalidTokens.add(failedToken);
            }
          });
        } catch (chunkError) {
          totalFailureCount += chunkTokens.length;
          chunkTokens.forEach((token) => failedTokens.push(token));
          console.error(
            `[공지 푸시][청크 ${chunkNumber}/${totalChunks}] 전송 자체 실패, 대상 ${chunkTokens.length}개`,
            chunkError
          );
        }
      }

      // 4. invalid token과 매핑된 users.fcmToken 정리 (배치 처리)
      let cleanedUserCount = 0;
      if (invalidTokens.size > 0) {
        const refsToClean = [];
        invalidTokens.forEach((token) => {
          const refs = tokenToUserRefs.get(token) || [];
          refs.forEach((ref) => refsToClean.push(ref));
        });

        for (let i = 0; i < refsToClean.length; i += CHUNK_SIZE) {
          const batch = db.batch();
          const refsChunk = refsToClean.slice(i, i + CHUNK_SIZE);
          refsChunk.forEach((ref) => {
            batch.update(ref, {
              fcmToken: admin.firestore.FieldValue.delete(),
            });
          });
          await batch.commit();
          cleanedUserCount += refsChunk.length;
        }

        console.log(
          `[공지 푸시] invalid token 정리 완료: 토큰 ${invalidTokens.size}개, 사용자 ${cleanedUserCount}명`
        );
      }

      // 5. 전체 집계 로그
      console.log(
        `[공지 푸시][집계] 대상: ${tokens.length}개, 성공: ${totalSuccessCount}개, 실패: ${totalFailureCount}개, 실패 토큰: ${failedTokens.length}개, invalid token: ${invalidTokens.size}개`
      );

      return {
        targetCount: tokens.length,
        successCount: totalSuccessCount,
        failureCount: totalFailureCount,
        failedTokenCount: failedTokens.length,
        invalidTokenCount: invalidTokens.size,
        cleanedUserCount: cleanedUserCount,
      };
    } catch (error) {
      console.error('알림 전송 실패:', error);
      return null;
    }
  }
);

// =============================================================================
// 도로 상태 이미지 업로드 시 Cache-Control 설정
// =============================================================================
exports.onRoadConditionImageFinalized = onObjectFinalized(async (event) => {
  const object = event.data;
  if (!object) return null;

  const name = object.name || '';
  const contentType = object.contentType || '';
  if (!contentType.startsWith('image/')) return null;
  if (!isRoadConditionImagePath(name)) return null;

  const currentCacheControl = object.cacheControl || '';
  if (currentCacheControl === ROAD_IMAGE_CACHE_CONTROL) return null;

  try {
    const bucket = object.bucket
      ? admin.storage().bucket(object.bucket)
      : admin.storage().bucket();
    await bucket.file(name).setMetadata({
      cacheControl: ROAD_IMAGE_CACHE_CONTROL,
    });
  } catch (error) {
    console.error('Cache-Control 설정 실패:', error);
  }

  return null;
});

// =============================================================================
// 문의 답변 등록 시 해당 사용자에게 알림
// =============================================================================
exports.onInquiryAnswered = onDocumentUpdated(
  {
    document: 'inquiries/{inquiryId}',
    database: 'eastapp-dev',
  },
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    const inquiryId = event.params.inquiryId;

    // 답변이 새로 등록된 경우만 처리 (pending → answered)
    if (before.status === 'answered' || after.status !== 'answered') {
      return null; // 이미 답변됨 또는 답변 아님
    }

    console.log(`문의 답변 등록: ${after.title}`);

    try {
      const userId = after.userId;

      // 1. 사용자 정보 조회
      const userDoc = await db.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        console.log('사용자를 찾을 수 없습니다');
        return null;
      }

      const user = userDoc.data();
      const fcmToken = user.fcmToken;
      const notificationSettings = user.notificationSettings || {};

      // 2. 알림 설정 확인
      if (!fcmToken) {
        console.log('FCM 토큰이 없습니다');
        return null;
      }

      if (
        notificationSettings.enabled !== true ||
        notificationSettings.inquiryReplies !== true
      ) {
        console.log('문의 답변 알림이 비활성화되어 있습니다');
        return null;
      }

      // 3. 메시지 구성 (inquiryId 포함)
      const message = {
        notification: {
          title: '문의 답변 도착',
          body: `"${after.title}" 문의에 답변이 등록되었습니다`,
        },
        data: {
          type: 'inquiry_reply',
          inquiryId: inquiryId, // 딥링크용 ID
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        token: fcmToken,
      };

      // 4. FCM 전송
      const response = await admin.messaging().send(message);

      console.log('문의 답변 알림 전송 성공:', response);

      return response;
    } catch (error) {
      console.error('알림 전송 실패:', error);

      // 토큰이 유효하지 않으면 Firestore에서 제거
      if (
        error.code === 'messaging/registration-token-not-registered' ||
        error.code === 'messaging/invalid-registration-token'
      ) {
        const userId = after.userId;
        await db.collection('users').doc(userId).update({
          fcmToken: admin.firestore.FieldValue.delete(),
        });
        console.log('유효하지 않은 토큰 삭제 완료');
      }

      return null;
    }
  }
);
