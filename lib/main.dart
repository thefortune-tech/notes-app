import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';
import 'dart:async';

// ─── Model ────────────────────────────────────────────────────────────────────

class Note {
  final String id;
  final String title;
  final String content;
  final String createdAt;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
  });

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      createdAt: json['createdAt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt,
    };
  }
}

// ─── Repository ───────────────────────────────────────────────────────────────

class NoteRepository {
  static const String _boxName = 'notesBox';

  Future<List<Note>> getNotes() async {
    final box = await Hive.openBox(_boxName);
    return box.values
        .map((e) => Note.fromJson(jsonDecode(e)))
        .toList();
  }

  Future<void> addNote(Note note) async {
    final box = await Hive.openBox(_boxName);
    await box.put(note.id, jsonEncode(note.toJson()));
  }

  Future<void> updateNote(Note note) async {
    final box = await Hive.openBox(_boxName);
    await box.put(note.id, jsonEncode(note.toJson()));
  }

  Future<void> deleteNote(String id) async {
    final box = await Hive.openBox(_boxName);
    await box.delete(id);
  }
}

// ─── Events ───────────────────────────────────────────────────────────────────

abstract class NoteEvent {}
class LoadNotes extends NoteEvent {}
class AddNote extends NoteEvent {
  final Note note;
  AddNote(this.note);
}
class UpdateNote extends NoteEvent {
  final Note note;
  UpdateNote(this.note);
}
class DeleteNote extends NoteEvent {
  final String id;
  DeleteNote(this.id);
}

// ─── States ───────────────────────────────────────────────────────────────────

abstract class NoteState {}
class NoteInitial extends NoteState {}
class NoteLoaded extends NoteState {
  final List<Note> notes;
  NoteLoaded(this.notes);
}

// ─── Bloc ─────────────────────────────────────────────────────────────────────

class NoteBloc extends Bloc<NoteEvent, NoteState> {
  final NoteRepository _repository;

  NoteBloc(this._repository) : super(NoteInitial()) {
    on<LoadNotes>((event, emit) async {
      final notes = await _repository.getNotes();
      emit(NoteLoaded(notes));
    });

    on<AddNote>((event, emit) async {
      await _repository.addNote(event.note);
      final notes = await _repository.getNotes();
      emit(NoteLoaded(notes));
    });

    on<UpdateNote>((event, emit) async {
      await _repository.updateNote(event.note);
      final notes = await _repository.getNotes();
      emit(NoteLoaded(notes));
    });

    on<DeleteNote>((event, emit) async {
      await _repository.deleteNote(event.id);
      final notes = await _repository.getNotes();
      emit(NoteLoaded(notes));
    });
  }
}

// ─── Router ───────────────────────────────────────────────────────────────────

final router = GoRouter(
  initialLocation: '/home',
  routes: [
    GoRoute(
      path: '/home',
      builder: (context, state) => const NotesListScreen(),
    ),
    GoRoute(
      path: '/add',
      builder: (context, state) => const NoteFormScreen(),
    ),
    GoRoute(
      path: '/edit/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return NoteFormScreen(noteId: id);
      },
    ),
  ],
);

// ─── Main ─────────────────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter Error: ${details.exception}');
    debugPrint('Stack trace: ${details.stack}');
  };

  runZonedGuarded(() async {
    await Hive.initFlutter();
    runApp(
      BlocProvider(
        create: (_) => NoteBloc(NoteRepository())..add(LoadNotes()),
        child: const MyApp(),
      ),
    );
  }, (error, stack) {
    debugPrint('Uncaught Error: $error');
    debugPrint('Stack trace: $stack');
  });
}

// ─── App ──────────────────────────────────────────────────────────────────────

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A1628),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('⛔', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              const Text(
                'Something went wrong',
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
              const SizedBox(height: 8),
              Text(
                details.exception.toString(),
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    };

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}

// ─── Notes List Screen ────────────────────────────────────────────────────────

class NotesListScreen extends StatelessWidget {
  const NotesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1628),
        title: const Text(
          'My Notes',
          style: TextStyle(color: Colors.white),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF378ADD),
        onPressed: () => context.go('/add'),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: BlocBuilder<NoteBloc, NoteState>(
        builder: (context, state) {
          if (state is NoteLoaded && state.notes.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('📝', style: TextStyle(fontSize: 64)),
                  SizedBox(height: 16),
                  Text(
                    'No notes yet\nTap + to add one',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }
          if (state is NoteLoaded) {
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.notes.length,
              itemBuilder: (context, index) {
                final note = state.notes[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:Color(0x14FFFFFF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              note.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.edit,
                              color: Color(0xFF378ADD),
                              size: 20,
                            ),
                            onPressed: () =>
                                context.go('/edit/${note.id}'),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.red,
                              size: 20,
                            ),
                            onPressed: () => context
                                .read<NoteBloc>()
                                .add(DeleteNote(note.id)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        note.content,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        note.createdAt,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          }
          return const SizedBox();
        },
      ),
    );
  }
}

// ─── Note Form Screen (Add & Edit) ────────────────────────────────────────────

class NoteFormScreen extends StatefulWidget {
  final String? noteId;
  const NoteFormScreen({super.key, this.noteId});

  @override
  State<NoteFormScreen> createState() => _NoteFormScreenState();
}

class _NoteFormScreenState extends State<NoteFormScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  Note? _existingNote;

  @override
  void initState() {
    super.initState();
    if (widget.noteId != null) {
      final state = context.read<NoteBloc>().state;
      if (state is NoteLoaded) {
        _existingNote = state.notes
            .firstWhere((n) => n.id == widget.noteId);
        _titleController.text = _existingNote!.title;
        _contentController.text = _existingNote!.content;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.noteId != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1628),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          isEditing ? 'Edit Note' : 'Add Note',
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Title',
                hintStyle:
                    TextStyle(color: Colors.white.withOpacity(0.4)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _contentController,
              style: const TextStyle(color: Colors.white),
              maxLines: 8,
              decoration: InputDecoration(
                hintText: 'Content',
                hintStyle:
                    TextStyle(color: Colors.white.withOpacity(0.4)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF378ADD),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  if (_titleController.text.isNotEmpty) {
                    if (isEditing) {
                      context.read<NoteBloc>().add(
                            UpdateNote(
                              Note(
                                id: _existingNote!.id,
                                title: _titleController.text,
                                content: _contentController.text,
                                createdAt: _existingNote!.createdAt,
                              ),
                            ),
                          );
                    } else {
                      context.read<NoteBloc>().add(
                            AddNote(
                              Note(
                                id: DateTime.now()
                                    .millisecondsSinceEpoch
                                    .toString(),
                                title: _titleController.text,
                                content: _contentController.text,
                                createdAt: DateTime.now()
                                    .toString()
                                    .substring(0, 10),
                              ),
                            ),
                          );
                    }
                    context.go('/home');
                  }
                },
                child: Text(
                  isEditing ? 'Update' : 'Add Note',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}