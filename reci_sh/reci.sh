#!/bin/zsh

echo "ssh -f integrity@redev.pascalpress.com.au -p 3004 -L 3456:localhost:80 -N"
ssh -f integrity@redev.pascalpress.com.au -p 3004 -L 3456:localhost:80 -N

echo "Opening in browser..."
open "http://reci-ext:3456"

echo "Showing tunnel(s):"
ps -ax | grep "ssh -f integrity@redev.pascalpress.com.au -p 3004 -L 3456:localhost:80 -N"

echo "Jenkins is now at http://reci-ext:3456"

