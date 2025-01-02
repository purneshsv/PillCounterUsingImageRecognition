import 'dart:core';
import 'package:flash/flash.dart';
import 'package:flutter/material.dart';
import 'package:basic_utils/basic_utils.dart';

class Util {
  static getFlashBar(context, message) {
    showFlash(
      context: context,
      duration: const Duration(seconds: 2),
      builder: (context, controller) {
        return Flash(
          margin: const EdgeInsets.all(8),
          backgroundColor: Colors.white,
          controller: controller,
          behavior: FlashBehavior.floating,
          position: FlashPosition.top,
          horizontalDismissDirection: HorizontalDismissDirection.horizontal,
          child: FlashBar(
            content: Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16)),
          ),
        );
      },
    );
  }
}