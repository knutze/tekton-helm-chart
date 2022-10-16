#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import os
import re
import sys
from pathlib import Path

OUT_DIR = Path(sys.argv[1])

KIND_ABBR = {
    "clusterrolebinding":             "crb",
    "configmap":                      "cm",
    "customresourcedefinition":       "crd",
    "deployment":                     "deploy",
    "mutatingwebhookconfiguration":   "mutwebhookcfg",
    "namespace":                      "ns",
    "rolebinding":                    "rb",
    "service":                        "svc",
    "serviceaccount":                 "sa",
    "validatingwebhookconfiguration": "valwebhookcfg",
}


def canonical_name(name, kind, apiver):
    name = str.replace(name, ':', '-')
    name = str.replace(name, os.pathsep, '-')
    if not kind:
        return name

    lk = str.lower(kind)
    suffix = KIND_ABBR.get(lk)
    if suffix == 'svc' and 'knative' in apiver:
        suffix = 'ksvc'
    if not suffix:
        suffix = lk

    return f"{name}-{suffix}"


def file_name(contents):
    # apiVersion: apps/v1
    # kind: Deployment
    # metadata:
    #   name: tekton-pipelines-webhook
    re_apiver = re.compile(r'^apiVersion:\s*([^\s]+)')
    re_kind = re.compile(r'^kind:\s*([^\s]+)')
    re_name = re.compile(r'^\s*name:\s*([^\s]+)')

    apiver = kind = name = ''
    for line in contents:
        if not apiver:
            m = re_apiver.match(line)
            apiver = m.group(1) if m else ''
        if not kind:
            m = re_kind.match(line)
            kind = m.group(1) if m else ''
        if not name:
            m = re_name.match(line)
            name = m.group(1) if m else ''
        if apiver and kind and name:
            break

    return canonical_name(name, kind, apiver) + '.yaml'


rstrip_stdin = map(str.rstrip, sys.stdin)

for line in rstrip_stdin:

    while line in ['', '---']:
        line = next(rstrip_stdin)

    contents = [line]
    for line in rstrip_stdin:
        if line == '---':
            if contents[-1] == '':
                del contents[-1]
            break
        contents.append(line)

    if not any(contents):
        continue

    with open(OUT_DIR/file_name(contents), 'w', newline='\n') as fout:
        for data in contents:
            print(data, file=fout)
