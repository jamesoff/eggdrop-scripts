#!/usr/local/bin/python

import sys
import re

def parse_log(filename):
    hosts = []

    try:
        fh = open(filename, 'r')
    except:
        print "Unable to open logfile"
        sys.exit(1)

    for line in fh:
        matches = re.search('joins \((.+)\)', line)
        if matches:
            hostname = matches.group(1)
            if not hostname in hosts:
                hosts.append(hostname)

    fh.close()
    return hosts

def main():
    hosts = parse_log(sys.argv[1])
    for host in hosts:
        print host

if __name__ == "__main__":
    main()
