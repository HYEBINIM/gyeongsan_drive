// lib/fun/top_100_list_screen.dart

import 'package:flutter/material.dart';
import '../models/place.dart';
import 'place_detail_screen.dart';

/// 인기 장소 100개 목록을 표시하는 화면
class Top100ListScreen extends StatelessWidget {
  final List<Place> allHotplaces;
  
  const Top100ListScreen({super.key, required this.allHotplaces});

  // 디자인 상수
  static const Color _primaryColor = Color(0xFF00C853);
  static const Color _backgroundColor = Color(0xFFF5F5F5);
  static const Color _cardColor = Colors.white;
  static const Color _textPrimaryColor = Color(0xFF212121);
  static const Color _textSecondaryColor = Color(0xFF757575);
  static const Color _dividerColor = Color(0xFFE0E0E0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text(
          '인기 장소 TOP 100',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _textPrimaryColor,
          ),
        ),
        backgroundColor: _cardColor,
        foregroundColor: _textPrimaryColor,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: _dividerColor,
            height: 1,
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: allHotplaces.length,
        itemBuilder: (context, index) {
          final place = allHotplaces[index];
          final bool isTop3 = index < 3;
          
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isTop3 ? _primaryColor : _backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isTop3 ? Colors.white : _textSecondaryColor,
                    ),
                  ),
                ),
              ),
              title: Text(
                place.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: _textPrimaryColor,
                ),
              ),
              subtitle: place.hashtags.isNotEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        place.hashtags.take(2).join(' '),
                        style: TextStyle(
                          color: _textSecondaryColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    )
                  : null,
              trailing: Icon(
                Icons.chevron_right,
                color: _textSecondaryColor,
                size: 20,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PlaceDetailScreen(place: place),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}