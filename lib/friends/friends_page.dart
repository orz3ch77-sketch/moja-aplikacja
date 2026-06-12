import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'friend_photo_picker.dart';
import '../shared/confirm_delete_dialog.dart';

class FriendsPage extends StatelessWidget {
  const FriendsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('friends');

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/pg.webp', fit: BoxFit.cover),
          ),
          Container(color: Colors.black.withValues(alpha: 0.36)),
          SafeArea(
            child: Column(
              children: [
                _FriendsHeader(
                  onBack: () => Navigator.pop(context),
                  onAdd: () => showFriendDialog(context),
                ),
                Expanded(
                  child: ValueListenableBuilder(
                    valueListenable: box.listenable(),
                    builder: (context, Box friendsBox, _) {
                      final friends = friendsBox.values
                          .map((value) {
                            return Map<String, dynamic>.from(value);
                          })
                          .toList()
                          .cast<Map<String, dynamic>>();

                      if (friends.isEmpty) {
                        return const _EmptyFriends();
                      }

                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 0.92,
                        ),
                        itemCount: friends.length,
                        itemBuilder: (context, index) {
                          return _FriendCard(
                            friend: friends[index],
                            onDelete: () async {
                              final confirmed = await confirmDeleteDialog(
                                context,
                              );
                              if (confirmed) {
                                await friendsBox.deleteAt(index);
                              }
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendsHeader extends StatelessWidget {
  const _FriendsHeader({
    required this.onBack,
    required this.onAdd,
  });

  final VoidCallback onBack;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: onBack,
          ),
          const Expanded(
            child: Text(
              'Moi znajomi',
              style: TextStyle(
                color: Colors.white,
                fontSize: 27,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Dodaj znajomego'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7C4DFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyFriends extends StatelessWidget {
  const _EmptyFriends();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: const Text(
          'Dodaj pierwszego znajomego.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
    );
  }
}

class _FriendCard extends StatelessWidget {
  const _FriendCard({
    required this.friend,
    required this.onDelete,
  });

  final Map<String, dynamic> friend;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final name = friend['name']?.toString() ?? '';
    final avatar = friend['avatar']?.toString() ?? 'female';
    final photoDataUrl = friend['photoDataUrl']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [Colors.white24, Colors.black26],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      offset: const Offset(4, 4),
                      blurRadius: 8,
                    ),
                    const BoxShadow(
                      color: Colors.white24,
                      offset: Offset(-2, -2),
                      blurRadius: 6,
                    ),
                  ],
                  border: Border.all(color: Colors.white70, width: 2),
                ),
                child: _FriendImage(
                  avatar: avatar,
                  photoDataUrl: photoDataUrl,
                  size: 118,
                ),
              ),
              Positioned(
                top: -10,
                right: -10,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'Usuń',
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 18,
                    ),
                    onPressed: onDelete,
                    constraints: const BoxConstraints(
                      minWidth: 34,
                      minHeight: 34,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            constraints: const BoxConstraints(maxWidth: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              name.isEmpty ? 'Bez imienia' : name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendImage extends StatelessWidget {
  const _FriendImage({
    required this.avatar,
    required this.photoDataUrl,
    required this.size,
  });

  final String avatar;
  final String photoDataUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final photoBytes = _dataUrlBytes(photoDataUrl);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white70, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: photoBytes == null
          ? Icon(
              avatar == 'male' ? Icons.man_rounded : Icons.woman_rounded,
              color: Colors.white,
              size: size * 0.66,
            )
          : Image.memory(photoBytes, fit: BoxFit.cover),
    );
  }

  Uint8List? _dataUrlBytes(String dataUrl) {
    if (!dataUrl.startsWith('data:image')) {
      return null;
    }

    final commaIndex = dataUrl.indexOf(',');
    if (commaIndex < 0) {
      return null;
    }

    return base64Decode(dataUrl.substring(commaIndex + 1));
  }
}

Future<void> showFriendDialog(BuildContext context) async {
  final nameController = TextEditingController();
  var avatar = 'female';
  var photoDataUrl = '';

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF151822),
            title: const Text(
              'Dodaj znajomego',
              style: TextStyle(color: Colors.white),
            ),
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      final selectedPhoto = await pickFriendPhotoDataUrl();
                      if (selectedPhoto == null) {
                        return;
                      }

                      setDialogState(() => photoDataUrl = selectedPhoto);
                    },
                    child: Container(
                      width: double.infinity,
                      height: 168,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white30),
                      ),
                      child: photoDataUrl.isEmpty
                          ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_outlined,
                                  color: Colors.white,
                                  size: 44,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Wklej lub wybierz zdjęcie',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ],
                            )
                          : Center(
                              child: _FriendImage(
                                avatar: avatar,
                                photoDataUrl: photoDataUrl,
                                size: 134,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          selected: avatar == 'female',
                          label: const Text('Kobieta'),
                          avatar: const Icon(Icons.woman_rounded),
                          onSelected: (_) {
                            setDialogState(() => avatar = 'female');
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ChoiceChip(
                          selected: avatar == 'male',
                          label: const Text('Mężczyzna'),
                          avatar: const Icon(Icons.man_rounded),
                          onSelected: (_) {
                            setDialogState(() => avatar = 'male');
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Imię',
                      labelStyle: const TextStyle(color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white30),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFB388FF)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Anuluj'),
              ),
              FilledButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) {
                    return;
                  }

                  await Hive.box('friends').add({
                    'name': name,
                    'avatar': avatar,
                    'photoDataUrl': photoDataUrl,
                    'createdAt': DateTime.now().toIso8601String(),
                  });

                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                },
                child: const Text('Zapisz'),
              ),
            ],
          );
        },
      );
    },
  );

  nameController.dispose();
}
