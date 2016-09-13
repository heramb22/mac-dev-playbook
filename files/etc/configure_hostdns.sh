#!/usr/bin/env bash

mkdir -v /etc/resolver
echo "nameserver 127.0.0.1" > /etc/resolver/loc
echo "port 35353" >> /etc/resolver/loc