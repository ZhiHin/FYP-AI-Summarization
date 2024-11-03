import 'package:flutter/material.dart';

class FileCard extends StatelessWidget {
  final String fileName;
  final String date;
  final String time;
  final String pages;
  final Function onEdit;
  final Function onDelete;

  const FileCard({
    super.key,
    required this.fileName,
    required this.date,
    required this.time,
    required this.pages,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.picture_as_pdf, color: Colors.blue),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fileName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text("Date: $date", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  Text("Time: $time", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ],
          ),
          Text(pages, style: const TextStyle(color: Colors.grey)),
          // Row(
          //   children: [
          //     IconButton(
          //       icon: const Icon(Icons.edit, color: Colors.green),
          //       onPressed: () => onEdit(),
          //     ),
          //     IconButton(
          //       icon: const Icon(Icons.delete, color: Colors.red),
          //       onPressed: () => onDelete(),
          //     ),
          //   ],
          // ),
        ],
      ),
    );
  }
}
