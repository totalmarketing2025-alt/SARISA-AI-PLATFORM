import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/search_case.dart';
import '../services/case_storage_service.dart';
import '../widgets/person_detection_photo_card.dart';

class CaseManagementPage extends StatefulWidget {
  const CaseManagementPage({super.key});

  @override
  State<CaseManagementPage> createState() => _CaseManagementPageState();
}

class _CaseManagementPageState extends State<CaseManagementPage> {
  final _storage = CaseStorageService.instance;
  late Future<List<SearchCase>> _casesFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _casesFuture = _storage.getCases();
  }

  String _newCaseNumber() {
    final now = DateTime.now();
    return 'SAR-${now.microsecondsSinceEpoch}';
  }

  Future<void> _createCase() async {
    final name = TextEditingController();
    final description = TextEditingController();
    final clothing = TextEditingController();
    final location = TextEditingController();
    final lastSeen = TextEditingController();

    final result = await showDialog<SearchCase>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('NEW SEARCH CASE'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Person name / identifier *',
                ),
              ),
              TextField(
                controller: description,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                ),
              ),
              TextField(
                controller: clothing,
                decoration: const InputDecoration(
                  labelText: 'Clothing / appearance',
                ),
              ),
              TextField(
                controller: location,
                decoration: const InputDecoration(
                  labelText: 'Last known location',
                ),
              ),
              TextField(
                controller: lastSeen,
                decoration: const InputDecoration(
                  labelText: 'Date and time last seen',
                  hintText: 'e.g. 03.11.2026, 18:30',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'The case is stored locally on this device.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('Enter a person name or identifier.'),
                  ),
                );
                return;
              }
              Navigator.pop(
                dialogContext,
                SearchCase(
                  caseNumber: _newCaseNumber(),
                  personName: name.text.trim(),
                  description: description.text.trim(),
                  clothing: clothing.text.trim(),
                  lastSeenLocation: location.text.trim(),
                  lastSeenAt: lastSeen.text.trim(),
                  createdAt: DateTime.now().toUtc().toIso8601String(),
                ),
              );
            },
            child: const Text('CREATE CASE'),
          ),
        ],
      ),
    );

    name.dispose();
    description.dispose();
    clothing.dispose();
    location.dispose();
    lastSeen.dispose();

    if (result == null || !mounted) return;

    try {
      await _storage.createCase(result);
      if (!mounted) return;
      setState(_refresh);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Search case saved successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create case: $e')),
      );
    }
  }

  Future<void> _openCase(SearchCase searchCase) async {
    final deleted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CaseDetailPage(searchCase: searchCase),
      ),
    );

    if (deleted == true && mounted) {
      setState(_refresh);
    } else if (mounted) {
      setState(_refresh);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'LOCATED':
        return Colors.greenAccent;
      case 'CLOSED':
        return Colors.grey;
      default:
        return Colors.orangeAccent;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _createCase,
      icon: const Icon(Icons.add),
      label: const Text('NEW CASE'),
    ),
    body: RefreshIndicator(
      onRefresh: () async => setState(_refresh),
      child: FutureBuilder<List<SearchCase>>(
        future: _casesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return ListView(
              children: [
                const SizedBox(height: 80),
                Center(child: Text('Database error: ${snapshot.error}')),
              ],
            );
          }

          final cases = snapshot.data ?? [];

          if (cases.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: const [
                SizedBox(height: 65),
                Icon(Icons.folder_open, size: 64, color: Colors.blueGrey),
                SizedBox(height: 16),
                Center(
                  child: Text(
                    'NO SEARCH CASES',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(height: 8),
                Center(
                  child: Text(
                    'Create a case to document a search operation and attach reference photographs.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.blueGrey),
                  ),
                ),
                SizedBox(height: 100),
              ],
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: cases.length,
            itemBuilder: (context, index) {
              final item = cases[index];
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(14),
                  leading: const CircleAvatar(
                    child: Icon(Icons.person_search),
                  ),
                  title: Text(
                    item.personName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.caseNumber),
                        if (item.lastSeenLocation.isNotEmpty)
                          Text('Last seen: ${item.lastSeenLocation}'),
                        const SizedBox(height: 5),
                        Text(
                          item.status,
                          style: TextStyle(
                            color: _statusColor(item.status),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openCase(item),
                ),
              );
            },
          );
        },
      ),
    ),
  );
}

class CaseDetailPage extends StatefulWidget {
  final SearchCase searchCase;

  const CaseDetailPage({super.key, required this.searchCase});

  @override
  State<CaseDetailPage> createState() => _CaseDetailPageState();
}

class _CaseDetailPageState extends State<CaseDetailPage> {
  final _storage = CaseStorageService.instance;
  late SearchCase _case;
  late Future<List<CasePhoto>> _photosFuture;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _case = widget.searchCase;
    _refreshPhotos();
  }

  void _refreshPhotos() {
    _photosFuture = _storage.getPhotos(_case.id!);
  }

  Future<void> _addPhotos() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: false,
    );

    if (result == null || !mounted) return;

    setState(() => _busy = true);
    int added = 0;

    try {
      for (final file in result.files) {
        final sourcePath = file.path;
        if (sourcePath == null) continue;

        await _storage.addPhoto(
          caseId: _case.id!,
          sourcePath: sourcePath,
        );
        added++;
      }

      if (!mounted) return;
      setState(() {
        _busy = false;
        _refreshPhotos();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$added photo(s) saved to this case.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _refreshPhotos();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Photo upload failed: $e')),
      );
    }
  }

  Future<void> _changeStatus(String? status) async {
    if (status == null) return;

    final updated = SearchCase(
      id: _case.id,
      caseNumber: _case.caseNumber,
      personName: _case.personName,
      description: _case.description,
      clothing: _case.clothing,
      lastSeenLocation: _case.lastSeenLocation,
      lastSeenAt: _case.lastSeenAt,
      status: status,
      createdAt: _case.createdAt,
    );

    try {
      await _storage.updateCase(updated);
      if (mounted) setState(() => _case = updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status update failed: $e')),
      );
    }
  }

  Future<void> _deletePhoto(CasePhoto photo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('DELETE PHOTO?'),
        content: const Text(
          'This will permanently delete this photo from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _storage.deletePhoto(photo.id!);
      if (mounted) setState(_refreshPhotos);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete photo: $e')),
      );
    }
  }

  Future<void> _deleteCase() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('DELETE SEARCH CASE?'),
        content: const Text(
          'The case and all photos stored inside it will be permanently deleted from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('DELETE CASE'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _storage.deleteCase(_case.id!);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete case: $e')),
      );
    }
  }

  Widget _info(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Colors.blueGrey,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(value),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('SEARCH CASE'),
      actions: [
        IconButton(
          tooltip: 'Delete case',
          onPressed: _deleteCase,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text(
          _case.personName,
          style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5),
        Text(
          _case.caseNumber,
          style: const TextStyle(color: Colors.blueGrey),
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CASE STATUS',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _case.status,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'ACTIVE',
                      child: Text('ACTIVE'),
                    ),
                    DropdownMenuItem(
                      value: 'LOCATED',
                      child: Text('LOCATED'),
                    ),
                    DropdownMenuItem(
                      value: 'CLOSED',
                      child: Text('CLOSED'),
                    ),
                  ],
                  onChanged: _changeStatus,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PERSON INFORMATION',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                _info('Description', _case.description),
                _info('Clothing / appearance', _case.clothing),
                _info('Last known location', _case.lastSeenLocation),
                _info('Date and time last seen', _case.lastSeenAt),
                _info('Created', _case.createdAt),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(
              child: Text(
                'REFERENCE PHOTOS',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: _busy ? null : _addPhotos,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('ADD PHOTOS'),
            ),
          ],
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.all(18),
            child: Center(child: CircularProgressIndicator()),
          ),
        const SizedBox(height: 10),
        FutureBuilder<List<CasePhoto>>(
          future: _photosFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Text('Could not load photos: ${snapshot.error}');
            }

            final photos = snapshot.data ?? [];

            if (photos.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No reference photos attached.',
                    style: TextStyle(color: Colors.blueGrey),
                  ),
                ),
              );
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.85,
              ),
              itemCount: photos.length,
              itemBuilder: (context, index) {
                final photo = photos[index];

                return PersonDetectionPhotoCard(
                  photo: photo,
                  onDelete: () => _deletePhoto(photo),
                );
              },
            );
          },
        ),
        const SizedBox(height: 30),
        const Text(
          'LOCAL STORAGE ONLY • PHOTOS ARE NOT UPLOADED TO A SERVER',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.blueGrey, fontSize: 9),
        ),
        const SizedBox(height: 20),
      ],
    ),
  );
}
