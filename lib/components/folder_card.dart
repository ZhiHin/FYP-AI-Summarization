import 'package:flutter/material.dart';

class FolderCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String count;
  final Color color;

  const FolderCard({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8.0),
      child: Stack(
        children: [
          // Folder tab (make it shorter)
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              width: 50, // Make the tab shorter by reducing width
              height: 20,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
            ),
          ),
          // Main folder body
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            width: 200, // Adjust the width of the main body to make it shorter
            height: 130,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            //child: SingleChildScrollView( // Wrap content in a scroll view
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Three-dot button at the top-right corner
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.more_vert),
                    color: Colors.white,
                    onPressed: () {
                      // Implement your action here
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // Row for icon and label + count column
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2), // Background color for the icon
                        shape: BoxShape.circle, // Circular shape
                      ),
                      child: Icon(
                        icon, // Document icon
                        size: 24,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Label
                          Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              overflow:
                                  TextOverflow.ellipsis, // Handle overflow
                            ),
                            maxLines: 2,
                            textAlign: TextAlign.start,
                          ),
                          const SizedBox(height: 2),
                          // Count
                          Text(
                            count,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              overflow: TextOverflow.ellipsis,
                            ),
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            //),
          ),
        ],
      ),
    );
  }
}
