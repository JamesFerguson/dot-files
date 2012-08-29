#!/bin/bash

cd ~/codez/dot-files/tweaks && \
chmod +x mvimf && \
cd /usr/local/bin && \
echo "sudo ln -s ~/codez/dot-files/tweaks/mvimf" && \
sudo ln -s ~/codez/dot-files/tweaks/mvimf
