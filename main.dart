import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:csv/csv.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? selectedFile;
  String? fileName;
  List<List<dynamic>>? uploadedCsvData; // Variable to store uploaded CSV data
  List<List<dynamic>>? cleanedCsvData; // Variable to store cleaned CSV data
  String? cleanedFilePath; // Path of the cleaned CSV file
  bool isCleaned = false; // State to track if cleaned file is ready
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  Future<void> pickAndUploadCSV() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      setState(() {
        selectedFile = file;
        fileName = result.files.single.name;
      });
      await loadCSVData(selectedFile!.path); // Load CSV data after picking
    }
  }

  Future<void> loadCSVData(String path) async {
    // Read the CSV file and parse its content
    final input = File(path).openRead();
    uploadedCsvData = await input
        .transform(utf8.decoder) // Decode bytes to UTF-8
        .transform(
            CsvToListConverter()) // Convert the CSV file to a list of lists
        .toList();

    setState(() {}); // Refresh the UI
  }

  void showUploadedCSVPreview() {
    if (uploadedCsvData != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CSVPreviewScreen(
              data: uploadedCsvData!, title: 'Uploaded CSV Preview'),
        ),
      );
    }
  }

  Future<void> removeDuplicates() async {
    if (selectedFile != null) {
      String fileContents = await selectedFile!.readAsString();

      // Send the file contents to the server
      final response = await http.post(
        Uri.parse('http://10.0.2.2:5000/remove_duplicates'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'file_contents': fileContents}),
      );

      if (response.statusCode == 200) {
        // Handle success, get cleaned CSV contents
        final responseData = jsonDecode(response.body);
        String cleanedCsv = responseData['cleaned_csv'];

        // Store the cleaned CSV data, but don't save it yet
        cleanedCsvData = CsvToListConverter().convert(cleanedCsv);

        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
              content: Text(
                  'Duplicates removed. You can now download the cleaned file.')),
        );

        setState(() {
          isCleaned = true; // Allow the download button to be shown
        });
      } else {
        // Handle error
        final errorData = jsonDecode(response.body);
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
              content:
                  Text('Failed to remove duplicates: ${errorData['error']}')),
        );
      }
    } else {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('No file selected to remove duplicates.')),
      );
    }
  }

  Future<void> downloadCleanedFile() async {
    if (cleanedCsvData != null) {
      String path = '${await getDownloadsDirectoryPath()}/cleaned_file.csv';
      String cleanedCsvString =
          const ListToCsvConverter().convert(cleanedCsvData!);

      File cleanedFile = File(path);
      await cleanedFile.writeAsString(cleanedCsvString);

      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('Cleaned file saved at: $path')),
      );

      setState(() {
        cleanedFilePath = path;
      });
    } else {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('No cleaned file available for download.')),
      );
    }
  }

  Future<String> getDownloadsDirectoryPath() async {
    Directory? directory;

    // For Android 10 and above
    if (Platform.isAndroid) {
      directory = Directory('/storage/emulated/0/Download');
    } else {
      // For older Android versions or other platforms
      directory = await getExternalStorageDirectory();
    }

    return directory!.path;
  }

  Future<void> loadCleanedCSVData(String path) async {
    // Read the cleaned CSV file and parse its content
    try {
      final input = File(path).openRead();
      cleanedCsvData = await input
          .transform(utf8.decoder) // Decode bytes to UTF-8
          .transform(
              CsvToListConverter()) // Convert the CSV file to a list of lists
          .toList();
      setState(() {});
    } catch (e) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('Error loading cleaned CSV: $e')),
      );
    }
  }

  void showCleanedCSVPreview() {
    if (cleanedCsvData != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CSVPreviewScreen(
              data: cleanedCsvData!, title: 'Cleaned CSV Preview'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        appBar: AppBar(title: Text('Data Sweep')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ElevatedButton(
                onPressed: pickAndUploadCSV,
                child: Text('Upload CSV File'),
              ),
              if (fileName != null) ...[
                SizedBox(height: 10),
                Text('Uploaded file: $fileName'),
                ElevatedButton(
                  onPressed: showUploadedCSVPreview,
                  child: Text('Preview Uploaded CSV'),
                ),
                ElevatedButton(
                  onPressed: removeDuplicates,
                  child: Text('Remove Duplicates'),
                ),
                if (isCleaned) ...[
                  SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: downloadCleanedFile, // New download button
                    child: Text('Download Cleaned File'),
                  ),
                ],
                if (cleanedCsvData != null) ...[
                  SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: showCleanedCSVPreview,
                    child: Text('Preview Cleaned CSV'),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class CSVPreviewScreen extends StatelessWidget {
  final List<List<dynamic>> data;
  final String title;

  const CSVPreviewScreen({Key? key, required this.data, required this.title})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal, // Enable horizontal scrolling
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical, // Enable vertical scrolling
            child: DataTable(
              columns: data.first
                  .map((column) => DataColumn(label: Text(column.toString())))
                  .toList(),
              rows: data.skip(1).map((row) {
                return DataRow(
                  cells: row
                      .map((cell) => DataCell(Text(cell.toString())))
                      .toList(),
                );
              }).toList(),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pop(
              context); // Back button to go back to the previous screen
        },
        child: Icon(Icons.arrow_back),
      ),
    );
  }
}
