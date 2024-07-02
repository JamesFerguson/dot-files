#!/bin/bash

cd $DOT_FILES_DIR/tweaks && \
chmod +x mvimf && \
cd /usr/local/bin && \
echo "sudo ln -s $DOT_FILES_DIR/tweaks/mvimf" && \
sudo ln -s $DOT_FILES_DIR/tweaks/mvimf
