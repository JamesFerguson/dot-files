#!/bin/zsh

# echo "ssh -f integrity@redev.pascalpress.com.au -p 3004 -L 3456:localhost:80 -N"
# ssh -f integrity@redev.pascalpress.com.au -p 3004 -L 3456:localhost:80 -N
# 
# echo "Opening in browser..."
# open "http://reci-ext:3456"
#
# echo "Showing tunnel(s):"
# ps -ax | grep "ssh -f integrity@redev.pascalpress.com.au -p 3004 -L 3456:localhost:80 -N"
# 
# echo "Jenkins is now at http://reci-ext:3456"

echo "sshuttle -r redev 192.168.0.6 192.168.0.13 &"
sshuttle -r redev 192.168.0.6 192.168.0.13 &

echo "Reci is now available at http://reci
