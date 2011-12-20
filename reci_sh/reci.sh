#!/bin/zsh

ssh -f integrity@redev.pascalpress.com.au -p 3004 -L 3456:localhost:80 -N

open "http://localhost:3456"

echo "Showing tunnel(s):"
ps -ax | grep "ssh -f integrity@redev.pascalpress.com.au -p 3004 -L 3456:localhost:80 -N"
