import 'package:flutter/material.dart';

/// Stable names are stored in the existing category icon field, never codepoints.
typedef CategoryIconOption = ({String id, String label, IconData icon});

const categoryIconOptions = <CategoryIconOption>[
  (id: 'restaurant', label: '식사 · 식비', icon: Icons.restaurant_rounded),
  (id: 'cafe', label: '카페 · 커피', icon: Icons.local_cafe_rounded),
  (id: 'bakery', label: '빵 · 간식', icon: Icons.bakery_dining_rounded),
  (id: 'grocery', label: '장보기 · 마트', icon: Icons.shopping_cart_rounded),
  (id: 'shopping', label: '쇼핑', icon: Icons.shopping_bag_rounded),
  (id: 'home', label: '집 · 주거 · 월세', icon: Icons.home_rounded),
  (id: 'utilities', label: '공과금 · 전기', icon: Icons.bolt_rounded),
  (id: 'water', label: '수도 · 물', icon: Icons.water_drop_rounded),
  (id: 'phone', label: '통신 · 휴대폰', icon: Icons.phone_android_rounded),
  (id: 'internet', label: '인터넷', icon: Icons.wifi_rounded),
  (id: 'furniture', label: '가구 · 인테리어', icon: Icons.chair_rounded),
  (id: 'laundry', label: '세탁 · 청소', icon: Icons.local_laundry_service_rounded),
  (id: 'bus', label: '버스 · 교통', icon: Icons.directions_bus_rounded),
  (id: 'train', label: '기차 · 지하철', icon: Icons.train_rounded),
  (id: 'car', label: '자동차', icon: Icons.directions_car_rounded),
  (id: 'taxi', label: '택시', icon: Icons.local_taxi_rounded),
  (id: 'fuel', label: '주유', icon: Icons.local_gas_station_rounded),
  (id: 'parking', label: '주차', icon: Icons.local_parking_rounded),
  (id: 'bicycle', label: '자전거', icon: Icons.directions_bike_rounded),
  (id: 'flight', label: '비행기 · 여행', icon: Icons.flight_rounded),
  (id: 'hotel', label: '숙박 · 호텔', icon: Icons.hotel_rounded),
  (id: 'health', label: '병원 · 의료', icon: Icons.local_hospital_rounded),
  (id: 'medicine', label: '약 · 약국', icon: Icons.medication_rounded),
  (id: 'fitness', label: '운동 · 헬스', icon: Icons.fitness_center_rounded),
  (id: 'beauty', label: '미용 · 뷰티', icon: Icons.face_retouching_natural_rounded),
  (id: 'hair', label: '미용실', icon: Icons.content_cut_rounded),
  (id: 'clothes', label: '의류 · 옷', icon: Icons.checkroom_rounded),
  (id: 'pets', label: '반려동물', icon: Icons.pets_rounded),
  (id: 'baby', label: '육아 · 아기', icon: Icons.child_care_rounded),
  (id: 'family', label: '가족', icon: Icons.family_restroom_rounded),
  (id: 'education', label: '교육 · 학원', icon: Icons.school_rounded),
  (id: 'book', label: '도서 · 책', icon: Icons.menu_book_rounded),
  (id: 'work', label: '업무 · 출장', icon: Icons.work_rounded),
  (id: 'computer', label: '컴퓨터 · 전자기기', icon: Icons.computer_rounded),
  (id: 'game', label: '게임 · 취미', icon: Icons.sports_esports_rounded),
  (id: 'movie', label: '영화 · 문화', icon: Icons.movie_rounded),
  (id: 'music', label: '음악', icon: Icons.music_note_rounded),
  (id: 'sports', label: '스포츠', icon: Icons.sports_soccer_rounded),
  (id: 'art', label: '미술 · 만들기', icon: Icons.palette_rounded),
  (id: 'camera', label: '사진 · 카메라', icon: Icons.photo_camera_rounded),
  (id: 'camping', label: '캠핑 · 야외', icon: Icons.terrain_rounded),
  (id: 'gift', label: '선물 · 경조사', icon: Icons.card_giftcard_rounded),
  (id: 'heart', label: '기부 · 사랑', icon: Icons.favorite_rounded),
  (id: 'flowers', label: '꽃 · 정원', icon: Icons.local_florist_rounded),
  (id: 'salary', label: '급여 · 월급', icon: Icons.payments_rounded),
  (
    id: 'allowance',
    label: '용돈 · 현금',
    icon: Icons.account_balance_wallet_rounded,
  ),
  (id: 'bank', label: '은행 · 이자', icon: Icons.account_balance_rounded),
  (id: 'savings', label: '저축 · 적금', icon: Icons.savings_rounded),
  (id: 'investment', label: '투자 · 주식', icon: Icons.trending_up_rounded),
  (id: 'insurance', label: '보험', icon: Icons.shield_rounded),
  (id: 'tax', label: '세금 · 납부', icon: Icons.request_quote_rounded),
  (id: 'subscription', label: '구독 · 정기결제', icon: Icons.subscriptions_rounded),
  (id: 'repair', label: '수리 · 공구', icon: Icons.build_rounded),
  (id: 'delivery', label: '배송 · 택배', icon: Icons.local_shipping_rounded),
  (id: 'celebration', label: '파티 · 기념일', icon: Icons.celebration_rounded),
  (id: 'star', label: '별', icon: Icons.star_rounded),
  (id: 'category', label: '일반 · 기타', icon: Icons.category_rounded),
];

CategoryIconOption? categoryIconById(String? id) {
  for (final option in categoryIconOptions) {
    if (option.id == id) return option;
  }
  return null;
}

IconData resolveCategoryIcon({
  String? id,
  String? name,
  String type = 'expense',
}) {
  if (type == 'transfer') return Icons.swap_horiz_rounded;
  final explicit = categoryIconById(id);
  if (explicit != null) return explicit.icon;
  final text = (name ?? '').toLowerCase();
  const aliases = <String, List<String>>{
    'cafe': ['카페', '커피', 'cafe', 'coffee'],
    'grocery': ['장보기', '마트', '식료', '생필', '생활'],
    'restaurant': ['식비', '식사', '외식', '음식', '배달', 'food'],
    'bakery': ['간식', '빵', '디저트'],
    'taxi': ['택시'],
    'train': ['지하철', '기차'],
    'fuel': ['주유'],
    'parking': ['주차'],
    'car': ['자동차', '차량'],
    'bus': ['교통', '버스', 'transport'],
    'home': ['주거', '월세', '관리비', '고정지출', '부동산'],
    'utilities': ['공과금', '전기', '가스'],
    'phone': ['통신', '휴대폰'],
    'internet': ['인터넷'],
    'health': ['의료', '병원', '건강'],
    'medicine': ['약국', '의약'],
    'fitness': ['운동', '헬스'],
    'beauty': ['미용', '뷰티'],
    'clothes': ['의류', '옷'],
    'pets': ['반려', '펫'],
    'baby': ['육아'],
    'family': ['가족'],
    'education': ['교육', '학원', '학비'],
    'book': ['도서', '독서'],
    'game': ['게임', '취미'],
    'movie': ['문화', '여가', '영화'],
    'music': ['음악'],
    'flight': ['여행', '항공'],
    'hotel': ['숙박'],
    'shopping': ['쇼핑', '구매'],
    'gift': ['경조사', '선물'],
    'heart': ['기부'],
    'salary': ['급여', '월급', '보너스', 'salary'],
    'allowance': ['용돈'],
    'bank': ['이자'],
    'savings': ['저축', '적금'],
    'investment': ['투자', '배당', '주식'],
    'insurance': ['보험'],
    'tax': ['세금'],
    'subscription': ['구독'],
    'work': ['업무', '출장'],
  };
  for (final entry in aliases.entries) {
    if (entry.value.any(text.contains)) {
      return categoryIconById(entry.key)!.icon;
    }
  }
  return type == 'income' ? Icons.payments_rounded : Icons.category_rounded;
}
