#!/bin/python3

VERSIONS = (
    ('9', '3.6'),
    ('10', '3.8'),
    ('11', '3.10'),
    ('12', 'edge'),
)


def render(dir_, postgres_version, alpine_version):
    with open(f'{dir_}/template.Dockerfile') as f:
        template = f.read()

    rendered = template.format(alpine_version=alpine_version)

    with open(f'{dir_}/{postgres_version}.Dockerfile', 'w') as f:
        f.write('# This file is generated from template.Dockerfile. Do not edit it directly.\n')
        f.write('###########################################################################\n\n')
        f.write(rendered)


if __name__ == '__main__':
    for versions in VERSIONS:
        render('backup', *versions)
        render('restore', *versions)
