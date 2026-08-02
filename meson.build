project(
  'sonictune',
  'c', 'cpp',
  version: '0.1.0',
  license: 'GPL-3.0-or-later',
  meson_version: '>=1.2.0',
  default_options: [
    'warning_level=2',
    'optimization=2',
    'b_lto=true',
  ],
)

project_version = meson.project_version()

# Directories
data_dir = get_option('datadir')
bindir = get_option('bindir')

# Install Python daemon + UI package
install_data(
  'src/sonictune/__init__.py',
  install_dir: get_option('prefix') / data_dir / 'sonictune',
)

# Install data files
install_data(
  'data/org.sonicTune.desktop',
  install_dir: data_dir / 'applications',
)

install_data(
  'data/org.sonicTune.appdata.xml',
  install_dir: get_option('prefix') / data_dir / 'metainfo',
)

install_data(
  'data/org.sonicTune.svg',
  install_dir: data_dir / 'icons' / 'hicolor' / 'scalable' / 'apps',
  rename: 'org.sonicTune.svg',
)

# Python entry point (wrapper script)
configure_file(
  input: 'scripts/sonictune.in',
  output: 'sonictune',
  configuration: configuration_data({
    'PYTHON': 'python3',
    'PREFIX': get_option('prefix'),
  }),
  install: true,
  install_dir: bindir,
)

message('SonicTune @0@ configured'.format(project_version))
