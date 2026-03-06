#!/bin/bash
echo "Running build_runner to generate files..."
dart run build_runner build --delete-conflicting-outputs
echo "Done!"
