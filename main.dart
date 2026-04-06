import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:korean_lunar_calendar/korean_lunar_calendar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 주의: 아래 Firebase.initializeApp()은 Firebase 콘솔에서 iOS 설정 후 
  // GoogleService-Info.plist 파일이 xcode 프로젝트에 추가되어야 정상 동작합니다.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase not initialized: $e");
  }
  runApp(const FamilyCalendarApp());
}

class FamilyCalendarApp extends StatelessWidget {
  const FamilyCalendarApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '가족 공유 달력',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
      ),
      home: const CalendarScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// 가족 구성원 데이터 모델
class FamilyMember {
  final String id;
  final String name;
  final Color color;

  FamilyMember(this.id, this.name, this.color);
}

// 가족 구성원 하드코딩
final List<FamilyMember> members = [
  FamilyMember('dad', '아빠', Colors.blue),
  FamilyMember('mom', '엄마', Colors.pink),
  FamilyMember('kid1', '첫째', Colors.green),
  FamilyMember('kid2', '둘째', Colors.orange),
];

// 법정 공휴일 데이터
const Map<String, String> holidays = {
  '01-01': '신정', '03-01': '3·1절', '05-05': '어린이날', '06-06': '현충일',
  '08-15': '광복절', '10-03': '개천절', '10-09': '한글날', '12-25': '성탄절',
  '2026-02-16': '설연휴', '2026-02-17': '설날', '2026-02-18': '설연휴',
  '2026-03-02': '대체공휴일', '2026-05-24': '부처님오신날', '2026-05-25': '대체공휴일',
  '2026-09-24': '추석연휴', '2026-09-25': '추석', '2026-09-26': '추석연휴'
};

String? getHolidayName(DateTime date) {
  final mmdd = DateFormat('MM-dd').format(date);
  final yyyymmdd = DateFormat('yyyy-MM-dd').format(date);
  return holidays[yyyymmdd] ?? holidays[mmdd];
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({Key? key}) : super(key: key);

  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  // 선택한 날짜에 해당하는 일정만 필터링하는 헬퍼 함수
  List<DocumentSnapshot> _getEventsForDay(
      List<DocumentSnapshot> allEvents, DateTime day) {
    return allEvents.where((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null || data['date'] == null) return false;
      
      final timestamp = data['date'] as Timestamp;
      final eventDate = timestamp.toDate();
      return isSameDay(eventDate, day);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('👨‍👩‍👧‍👦 우리 가족 달력'),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Firestore events 컬렉션 구독 (날짜 순 정렬)
        stream: FirebaseFirestore.instance.collection('events').orderBy('date').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('데이터를 불러오는데 실패했습니다.'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allEvents = snapshot.data?.docs ?? [];
          final selectedDateTarget = _selectedDay ?? _focusedDay;
          final selectedDayEvents = _getEventsForDay(allEvents, selectedDateTarget);
          final String? selectedHoliday = getHolidayName(selectedDateTarget);

          return Column(
            children: [
              TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                locale: 'ko_KR', // intl 패키지를 통해 한국어 적용 (pubspec 연동 필요)
                holidayPredicate: (day) => getHolidayName(day) != null,
                calendarStyle: const CalendarStyle(
                  holidayTextStyle: TextStyle(color: Colors.red),
                  weekendTextStyle: TextStyle(color: Colors.red),
                ),
                selectedDayPredicate: (day) {
                  return isSameDay(_selectedDay, day);
                },
                onDaySelected: (selectedDay, focusedDay) {
                  if (!isSameDay(_selectedDay, selectedDay)) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  }
                },
                onFormatChanged: (format) {
                  if (_calendarFormat != format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  }
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },
                eventLoader: (day) {
                  return _getEventsForDay(allEvents, day);
                },
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, date, events) {
                    final holiday = getHolidayName(date);
                    
                    // 음력 계산
                    final lunar = KoreanLunarCalendar();
                    lunar.setSolarDate(date.year, date.month, date.day);
                    final String lunarStr = '${lunar.lunarMonth}.${lunar.lunarDay}';

                    return SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            top: 0,
                            right: 2,
                            child: Text(
                              lunarStr,
                              style: TextStyle(
                                fontSize: 8,
                                color: isSameDay(date, _selectedDay) ? Colors.white70 : Colors.grey,
                              ),
                            ),
                          ),
                          if (holiday != null || events.isNotEmpty)
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (holiday != null)
                                    Text(
                                      holiday,
                                      style: TextStyle(
                                        fontSize: 8, 
                                        color: isSameDay(date, _selectedDay) ? Colors.red[200] : Colors.red,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  if (events.isNotEmpty)
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: events.take(4).map((event) {
                                        final data = (event as DocumentSnapshot).data() as Map<String, dynamic>;
                                        final memberId = data['memberId'] ?? 'dad';
                                        final member = members.firstWhere((m) => m.id == memberId, orElse: () => members[0]);
                                        
                                        return Container(
                                          margin: const EdgeInsets.symmetric(horizontal: 1.5, vertical: 2),
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: member.color,
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const Divider(),
              Expanded(
                child: selectedDayEvents.isEmpty 
                  ? Center(
                      child: Text(
                        selectedHoliday != null 
                          ? '🎉 오늘은 $selectedHoliday 입니다!\n등록된 일정이 없습니다.' 
                          : '선택한 날짜에 일정이 없습니다.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: selectedHoliday != null ? Colors.red : null),
                      ),
                    )
                  : ListView.builder(
                    itemCount: selectedDayEvents.length,
                    itemBuilder: (context, index) {
                      final doc = selectedDayEvents[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final memberId = data['memberId'] ?? 'dad';
                      final member = members.firstWhere((m) => m.id == memberId, orElse: () => members[0]);
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: member.color.withOpacity(0.2),
                            child: Text(
                              member.name.substring(0, 1), 
                              style: TextStyle(color: member.color, fontWeight: FontWeight.bold)
                            ),
                          ),
                          title: Text(data['title'] ?? '제목 없음', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(member.name),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.grey),
                            onPressed: () => _deleteEvent(context, doc.reference),
                          ),
                        ),
                      );
                    },
                  ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEventDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('일정 추가'),
      ),
    );
  }

  void _deleteEvent(BuildContext context, DocumentReference ref) {
    showDialog(
      context: context, 
      builder: (context) => AlertDialog(
        title: const Text('일정 삭제'),
        content: const Text('해당 일정을 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () {
              ref.delete();
              Navigator.pop(context);
            }, 
            child: const Text('삭제', style: TextStyle(color: Colors.red))
          ),
        ],
      )
    );
  }

  void _showAddEventDialog(BuildContext context) {
    String title = '';
    String selectedMemberId = members[0].id;
    final date = _selectedDay ?? _focusedDay;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('${DateFormat('MM월 dd일').format(date)}${getHolidayName(date) != null ? ' (${getHolidayName(date)})' : ''} 일정 등록'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: '어떤 일정인가요?',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      title = val;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedMemberId,
                    decoration: const InputDecoration(
                      labelText: '누구의 일정인가요?',
                      border: OutlineInputBorder(),
                    ),
                    items: members.map((member) {
                      return DropdownMenuItem<String>(
                        value: member.id,
                        child: Row(
                          children: [
                            Container(width: 16, height: 16, decoration: BoxDecoration(color: member.color, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Text(member.name),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          selectedMemberId = val;
                        });
                      }
                    },
                  )
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (title.isNotEmpty) {
                      await FirebaseFirestore.instance.collection('events').add({
                        'title': title,
                        'date': Timestamp.fromDate(date),
                        'memberId': selectedMemberId,
                      });
                      if (context.mounted) Navigator.of(context).pop();
                    }
                  },
                  child: const Text('저장'),
                ),
              ],
            );
          }
        );
      },
    );
  }
}
