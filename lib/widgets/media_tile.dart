import 'package:flutter/material.dart';
import '../models/media_file.dart';

class MediaTile extends StatelessWidget {
  const MediaTile(
      {super.key,
      required this.media,
      required this.favorite,
      required this.onTap,
      required this.onFavorite});
  final MediaFile media;
  final bool favorite;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(media.type == MediaType.video
            ? Icons.movie_rounded
            : Icons.music_note_rounded),
      ),
      title: Text(media.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
          '${media.folderName} • ${media.formattedSize} • ${media.extension}'),
      trailing: IconButton(
          icon: Icon(favorite ? Icons.favorite : Icons.favorite_border),
          onPressed: onFavorite),
      onTap: onTap,
    );
  }
}
