import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../../models/safe_home_settings.dart';
import '../../utils/constants.dart';
import '../../utils/snackbar_utils.dart';

/// 비상 지인 연락망 Bottom Sheet
/// 연락처 추가/삭제 기능 지원
class EmergencyContactsBottomSheet extends StatefulWidget {
  final List<EmergencyContact> initialContacts;
  final Future<void> Function(String name, String phone) onAdd;
  final Future<void> Function(int index) onRemove;

  const EmergencyContactsBottomSheet({
    super.key,
    required this.initialContacts,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  State<EmergencyContactsBottomSheet> createState() =>
      _EmergencyContactsBottomSheetState();
}

class _EmergencyContactsBottomSheetState
    extends State<EmergencyContactsBottomSheet> {
  late List<EmergencyContact> _contacts;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _contacts = List.from(widget.initialContacts);
  }

  /// 연락처 선택 및 추가
  Future<void> _pickContact() async {
    setState(() => _isLoading = true);

    try {
      // 권한 요청 (읽기 전용만 요청하여 ANDROID에서 WRITE_CONTACTS 미선언 이슈 방지)
      // 참고: flutter_contacts 기본값은 읽기+쓰기 요청이므로 Manifest에 WRITE_CONTACTS가 없으면 false가 반환될 수 있음
      final permission = await FlutterContacts.requestPermission(
        readonly: true,
      );
      if (!permission) {
        if (mounted) {
          SnackBarUtils.showWarning(context, '연락처 접근 권한이 필요합니다');
        }
        return;
      }

      // 연락처 선택 UI 열기
      final contact = await FlutterContacts.openExternalPick();
      if (contact == null) {
        // 사용자가 취소한 경우
        return;
      }

      // 선택한 연락처 상세 정보 가져오기 (전화번호 등 속성 포함)
      final fullContact = await FlutterContacts.getContact(
        contact.id,
        withProperties: true,
      );
      if (fullContact == null) {
        if (mounted) {
          SnackBarUtils.showError(context, '연락처 정보를 가져올 수 없습니다');
        }
        return;
      }

      // 이름과 전화번호 추출
      final name = fullContact.displayName;
      final phone = fullContact.phones.isNotEmpty
          ? fullContact.phones.first.number
          : '';

      if (name.isEmpty || phone.isEmpty) {
        if (mounted) {
          SnackBarUtils.showError(context, '이름 또는 전화번호가 없는 연락처입니다');
        }
        return;
      }

      // 중복 체크
      final isDuplicate = _contacts.any((c) => c.phone == phone);
      if (isDuplicate) {
        if (mounted) {
          SnackBarUtils.showWarning(context, '이미 등록된 연락처입니다');
        }
        return;
      }

      // 콜백 호출
      await widget.onAdd(name, phone);

      // 로컬 상태 업데이트
      if (mounted) {
        setState(() {
          _contacts.add(EmergencyContact(name: name, phone: phone));
        });
        SnackBarUtils.showSuccess(context, '$name님이 추가되었습니다');
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, '연락처 추가 실패: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 연락처 삭제
  Future<void> _removeContact(int index) async {
    final contact = _contacts[index];

    // 삭제 확인 다이얼로그
    final confirmed = await _showDeleteConfirmDialog(contact.name);
    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);

    try {
      // 콜백 호출
      await widget.onRemove(index);

      // 로컬 상태 업데이트
      if (mounted) {
        setState(() {
          _contacts.removeAt(index);
        });
        SnackBarUtils.showSuccess(context, '${contact.name}님이 삭제되었습니다');
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, '연락처 삭제 실패: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 삭제 확인 다이얼로그
  Future<bool?> _showDeleteConfirmDialog(String name) {
    final colorScheme = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          title: Text(
            '연락처 삭제',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontFamily: AppConstants.fontFamilySmall,
            ),
          ),
          content: Text(
            '$name님을 비상 연락처에서 삭제하시겠습니까?',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontFamily: AppConstants.fontFamilySmall,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                '취소',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontFamily: AppConstants.fontFamilySmall,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                '삭제',
                style: TextStyle(
                  color: colorScheme.error,
                  fontWeight: FontWeight.w600,
                  fontFamily: AppConstants.fontFamilySmall,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenHeight = MediaQuery.of(context).size.height;

    // 한국어 주석: 뒤로가기 버튼으로 바텀시트 닫기 허용
    return SafeArea(
      top: true,
      bottom: true,
      child: PopScope(
        canPop: true,
        child: Container(
          height: screenHeight * 0.70, // 화면의 70% 높이
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  // AppBar
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      border: Border(
                        bottom: BorderSide(
                          color: colorScheme.outlineVariant,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '비상 지인 연락망',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                                fontFamily: AppConstants.fontFamilySmall,
                              ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(Icons.close, color: colorScheme.onSurface),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),

                  // 연락처 목록
                  Expanded(
                    child: _contacts.isEmpty
                        ? _buildEmptyState(colorScheme)
                        : _buildContactsList(colorScheme),
                  ),
                ],
              ),

              // 로딩 인디케이터
              if (_isLoading)
                Container(
                  color: Colors.black26,
                  child: const Center(child: CircularProgressIndicator()),
                ),

              // FloatingActionButton
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton(
                  onPressed: _isLoading ? null : _pickContact,
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  child: const Icon(Icons.person_add),
                ),
              ),
            ],
          ),
        ),
      ), // PopScope
    ); // SafeArea
  }

  /// 빈 상태 위젯
  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_off_outlined,
            size: 80,
            color: colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            '등록된 비상 연락처가 없습니다',
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurfaceVariant,
              fontFamily: AppConstants.fontFamilySmall,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '+ 버튼을 눌러 연락처를 추가하세요',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.outline,
              fontFamily: AppConstants.fontFamilySmall,
            ),
          ),
        ],
      ),
    );
  }

  /// 연락처 목록 위젯
  Widget _buildContactsList(ColorScheme colorScheme) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _contacts.length,
      separatorBuilder: (context, index) =>
          Divider(height: 1, color: colorScheme.outlineVariant),
      itemBuilder: (context, index) {
        final contact = _contacts[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: colorScheme.primaryContainer,
            foregroundColor: colorScheme.onPrimaryContainer,
            child: Text(
              contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontFamily: AppConstants.fontFamilySmall,
              ),
            ),
          ),
          title: Text(
            contact.name,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w500,
              fontFamily: AppConstants.fontFamilySmall,
            ),
          ),
          subtitle: Text(
            contact.phone,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontFamily: AppConstants.fontFamilySmall,
            ),
          ),
          trailing: IconButton(
            icon: Icon(Icons.delete_outline, color: colorScheme.error),
            onPressed: _isLoading ? null : () => _removeContact(index),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
        );
      },
    );
  }
}
