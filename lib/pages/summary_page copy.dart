import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tepovka/pages/intro_page.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:tepovka/home.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:tepovka/pages/about.dart';

import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';

import 'package:health/health.dart';

import 'package:tepovka/ppg_algo.dart';

class Summary extends StatefulWidget {
  final double averageBPM;
  final List<double> data;
  final List<int> bpm_list;
  final List<double> frames;

  const Summary({
    Key? key,
    required this.averageBPM,
    required this.data,
    required this.bpm_list,
    required this.frames,
  }) : super(key: key);

  @override
  State<Summary> createState() => _SummaryState();
}

class _SummaryState extends State<Summary> {
  int _selectedIndex = 0;
  final Health _health = Health();

  List<HealthDataPoint> _healthDataList = [];

  bool _isSaving = false;
  final TextEditingController _notesController = TextEditingController();
  double? _rmssd;

  @override
  void initState() {
    print('bpm_list: ${widget.bpm_list}');
    //print('red_channel: ${widget.data}');
    print('Délka dat: ${widget.data.length}');
    super.initState();

    _rmssd = _calculateRMSSD();
    _authorizeHealth();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  double _calculateRMSSD() {
    final validBpm = widget.bpm_list.where((bpm) => bpm > 0).toList();
    if (validBpm.length < 2) return 0.0;
    final rrIntervals = validBpm.map((bpm) => 60000 / bpm.toDouble()).toList();
    final differences = <double>[];
    for (int i = 0; i < rrIntervals.length - 1; i++) {
      differences.add(rrIntervals[i + 1] - rrIntervals[i]);
    }
    final sumSq = differences.fold(0.0, (sum, diff) => sum + diff * diff);
    return sqrt(sumSq / differences.length);
  }

  Future<void> _authorizeHealth() async {
    // Seznam datových typů, které chceme zapisovat nebo číst
    final types = [
      HealthDataType.HEART_RATE,
    ];

    final permissionGranted = await _health.requestAuthorization(
      [HealthDataType.HEART_RATE],
      permissions: [HealthDataAccess.READ_WRITE],
    );
    if (!permissionGranted) {
      print('Oprávnění k zápisu do Apple Health nebylo uděleno.');
      return;
    }

    // Požádat o oprávnění
    bool requested = await _health.requestAuthorization(types);
    if (!requested) {
      print('Uživatel odmítl přístup k HealthKit');
    } else {
      print('HealthKit autorizace proběhla úspěšně');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const IntroPage()),
        );
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const Home()),
        );
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const About()),
        );
        break;
    }
  }

  Future<void> _saveMeasurement() async {
    if (_isSaving) {
      print('Ukládání již probíhá.');
      return;
    }
    _isSaving = true;

    try {
      print('Začátek ukládání měření');

      // Získání adresáře aplikace
      final directory = await getApplicationDocumentsDirectory();

      // Cesta k jedinému souboru pro měření
      final summaryFile = File('${directory.path}/measurement_summary.json');

      // Formátování aktuálního času
      final now = DateTime.now();
      final formattedDate =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final formattedTime =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

      // Data pro záznam
      final averageBpm = widget.averageBPM.toInt();
      final dataForPlot = widget.data; // Ponecháme seznam jako list čísel
      final notesContent = _notesController.text;
      final bpmList = widget.bpm_list;
      final frames = widget.frames.skip(2).toList();

      // Sestavení záznamu ve formátu Map
      final record = {
        'date': formattedDate,
        'time': formattedTime,
        'averageBPM': averageBpm,
        'dataForPlot': dataForPlot,
        // Přidáno bpm_list
        'notes': notesContent,
        'bpmList': bpmList,
        'frames': frames,
        'hrvRmssd': _rmssd,
      };

      // Pokud soubor již existuje, načteme jeho obsah
      List<dynamic> existingRecords = [];
      if (await summaryFile.exists()) {
        final content = await summaryFile.readAsString();
        existingRecords =
            json.decode(content); // Načteme existující záznamy jako seznam
      }

      // Přidáme nový záznam do seznamu
      existingRecords.add(record);

      // Uložíme všechny záznamy zpět do souboru jako JSON
      await summaryFile.writeAsString(json.encode(existingRecords),
          mode: FileMode.write);

      print('Ukládání úspěšně dokončeno');
    } catch (e) {
      print('Chyba při ukládání: $e');
    } finally {
      _isSaving = false;
    }
  }

  Future<void> _saveToAppleHealth(double bpm) async {
    final now = DateTime.now();
    final start = DateTime.now().subtract(Duration(seconds: 30));
    final bpmValue = bpm.toInt();

    bool success = await _health.writeHealthData(
      value: bpmValue.toDouble(),
      type: HealthDataType.HEART_RATE,
      startTime: now,
    );

    if (success) {
      print('Tepová frekvence byla úspěšně uložena do Apple Health');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Text(
                'Úspěšně uloženo do Apple Health',
                style:
                    TextStyle(color: const Color.fromARGB(255, 192, 192, 192)),
              ),
              SizedBox(
                width: 50,
              ),
              Image.asset(
                'assets/Icon - Apple Health.png', // Cesta k obrázku
                width: 24, // Nastavte velikost obrázku
                height: 24, // Nastavte velikost obrázku
              ),
            ],
          ),
          backgroundColor: const Color.fromARGB(255, 54, 54, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            // Zaoblené rohy
          ),
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      print('Nepodařilo se uložit do Apple Health');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chyba při ukládání do Apple Health'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Skrytí klávesnice při kliknutí mimo textové pole
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: const Color.fromARGB(255, 242, 242, 242),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: const Color.fromARGB(255, 242, 242, 242),
          centerTitle: true,
          title: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'VÝSLEDEK',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
        ),
        body: SingleChildScrollView(
            child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // BPM Display
            Container(
              margin: const EdgeInsets.only(top: 20),
              child: Column(
                children: [
                  const Text(
                    'Průměrná tepová frekvence:',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 20,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${widget.averageBPM.toInt()} bpm',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 40,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'HRV (RMSSD): ${_rmssd?.toStringAsFixed(1) ?? 'N/A'} ms',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 18,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Gradient BPM Bar
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
              child: Container(
                height: 40,
                width: double.infinity, // Full width
                decoration: BoxDecoration(
                  color: Colors.grey[300], // Light grey background
                  borderRadius: BorderRadius.circular(10), // Rounded corners
                ),
                child: Stack(
                  children: [
                    // Background gradient (color zones)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.red.withOpacity(1), // Red (30-50 bpm)
                              Colors.orange
                                  .withOpacity(1), // Orange (50-60 bpm)
                              Colors.green.withOpacity(1), // Green (60-130 bpm)
                              Colors.orange
                                  .withOpacity(1), // Orange (130-170 bpm)
                              Colors.red.withOpacity(1), // Red (170-220 bpm)
                            ],
                            stops: const [
                              0.0,
                              0.11,
                              0.20,
                              0.55,
                              0.75,
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    // Inner marker for average BPM
                    Positioned(
                      left: ((widget.averageBPM.clamp(30, 220) - 30) /
                              (220 - 30)) *
                          (MediaQuery.of(context).size.width -
                              40), // Normalize position
                      child: Container(
                        width: 10,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white, // Marker color
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    Center(
                      child: Text(
                        '${widget.averageBPM.toInt()} bpm',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    // Text on the left (30)
                    const Positioned(
                      left: 10,
                      top: 10,
                      child: Text(
                        '30',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    // Text on the right (220)
                    const Positioned(
                      right: 10,
                      top: 10,
                      child: Text(
                        '220',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _notesController,
                style: const TextStyle(
                  color: Colors.black, // Barva textu v poli
                ),
                cursorColor: Colors.grey,
                decoration: InputDecoration(
                  labelText: 'Poznámka',
                  labelStyle: const TextStyle(
                    color: Color.fromARGB(255, 110, 109, 109), // Barva štítku
                  ),
                  hintText: 'Zadejte své poznámky k měření...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: const BorderSide(
                      color: Colors.grey, // Barva základního ohraničení
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: const BorderSide(
                      color:
                          Colors.grey, // Barva ohraničení při aktivním vstupu
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: const BorderSide(
                      color: Color.fromARGB(
                          255, 110, 109, 109), // Barva ohraničení při zaostření
                      width: 1.5, // Šířka ohraničení při zaostření
                    ),
                  ),
                  fillColor: Colors.white,
                ),
                maxLines: null, // Povolení víceradkového vstupu
              ),
            ),
            SizedBox(
              height: 300,
              width: widget.data.length.toDouble() * 5,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Scrollbar(
                  thumbVisibility: true, // Zobrazení posuvníku
                  controller:
                      ScrollController(), // Připojení k ovládání scrollování
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: widget.data.length.toDouble(),
                      child: Builder(
                        builder: (context) {
                          int totalPoints = widget.data.length;
                          int centerIndex = totalPoints ~/ 2;
                          int range = (totalPoints * 0.2).toInt();
                          int startIndex = (centerIndex - range ~/ 2)
                              .clamp(0, totalPoints - 1);
                          int endIndex = (centerIndex + range ~/ 2)
                              .clamp(0, totalPoints - 1);

                          List<double> middleData =
                              widget.data.sublist(startIndex, endIndex);
                          double minValue =
                              middleData.reduce((a, b) => a < b ? a : b);
                          double maxValue =
                              middleData.reduce((a, b) => a > b ? a : b);

                          return LineChart(
                            LineChartData(
                              gridData: const FlGridData(show: false),
                              borderData: FlBorderData(show: false),
                              titlesData: const FlTitlesData(show: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: widget.data
                                      .asMap()
                                      .entries
                                      .map(
                                        (entry) => FlSpot(
                                          entry.key.toDouble(),
                                          entry.value * -1,
                                        ),
                                      )
                                      .toList(),
                                  isCurved: true,
                                  color: Colors.red,
                                  dotData: FlDotData(show: false),
                                ),
                              ],
                              extraLinesData: ExtraLinesData(
                                verticalLines: widget.bpm_list
                                    .asMap()
                                    .entries
                                    .map((entry) {
                                  int index = entry.key;
                                  int bpmValue = entry.value;

                                  return VerticalLine(
                                    x: (index + 1) *
                                        150.toDouble(), // Pozice na ose X
                                    color: Colors.blue,
                                    strokeWidth: 1,
                                    dashArray: [5, 5], // Tečkovaná čára
                                    label: VerticalLineLabel(
                                      show: true,
                                      labelResolver: (line) =>
                                          'BPM = $bpmValue',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              lineTouchData:
                                  const LineTouchData(enabled: false),
                              minX: 0,
                              maxX: widget.data.length.toDouble(),
                              minY: (maxValue + 1) * -1,
                              maxY: (minValue - 1) * -1,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Text Field for Notes

            // Home Button
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.center, // Center both elements
              children: [
                IconButton(
                  icon: const Icon(
                    Symbols.heart_broken,
                    size: 30,
                  ),
                  color: const Color.fromARGB(255, 222, 16, 1),
                  onPressed: () async {
                    // Uložit do Apple Health
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const IntroPage()),
                    );
                  },
                ),

                // Space between icon and text
                InkWell(
                  onTap: () async {
                    // Uložit do Apple Health
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const IntroPage()),
                    );
                  },
                  child: AnimatedScale(
                    duration: const Duration(
                        milliseconds: 100), // Duration of the effect
                    scale: _isSaving
                        ? 1.0
                        : 1.1, // Slightly increase the size when pressed
                    child: const Text(
                      'Zrušit',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: const Color.fromARGB(255, 222, 16, 1),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 50,
                ),
                IconButton(
                  icon: const Icon(
                    Symbols.heart_plus,
                    size: 45,
                  ),
                  color: Colors.blue,
                  onPressed: _isSaving
                      ? null
                      : () async {
                          await _saveMeasurement(); // Uložit data lokálně
                          await _saveToAppleHealth(
                              widget.averageBPM); // Uložit do Apple Health
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const IntroPage()),
                          );
                        },
                ),

                // Space between icon and text
                InkWell(
                  onTap: _isSaving
                      ? null
                      : () async {
                          await _saveMeasurement(); // Uložit data lokálně
                          await _saveToAppleHealth(
                              widget.averageBPM); // Uložit do Apple Health
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const IntroPage()),
                          );
                        },
                  child: AnimatedScale(
                    duration: const Duration(
                        milliseconds: 100), // Duration of the effect
                    scale: _isSaving
                        ? 1.0
                        : 1.1, // Slightly increase the size when pressed
                    child: const Text(
                      'Uložit',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ),
              ],
            )
          ],
        )),
        bottomNavigationBar: GNav(
          tabMargin: const EdgeInsets.symmetric(horizontal: 10),
          gap: 0,
          activeColor: Colors.black,
          iconSize: 24,
          backgroundColor: Colors.white,
          color: Colors.grey,
          selectedIndex: _selectedIndex,
          onTabChange: _onItemTapped,
          tabs: const [
            GButton(
              icon: Symbols.family_home,
              text: 'MENU',
            ),
            GButton(
              icon: Symbols.ecg_heart,
              text: 'MĚŘENÍ',
            ),
            GButton(
              icon: Symbols.help,
              text: 'INFO',
            ),
          ],
        ),
      ),
    );
  }
}
