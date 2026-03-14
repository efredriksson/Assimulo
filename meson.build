project(
  'Assimulo',
  ['c', 'cython', 'fortran'],
  version: '3.7.0.dev0',
  meson_version: '>=1.4'
)

py = import('python').find_installation(pure: false)
fs = import('fs')
cc = meson.get_compiler('c')

# --- NumPy include dir ---
numpy_inc = run_command(
  py, ['-c', 'import numpy; print(numpy.get_include())'],
  check: true
).stdout().strip()

# --- Common flags ---
# numpy_inc is passed via -I because it may live inside the source tree (e.g. in a
# local venv), which meson's include_directories() disallows for absolute paths.
common_c_args = ['-fno-strict-aliasing', '-I' + numpy_inc]

if get_option('debug')
  common_c_args += ['-g']
  common_link_args = ['-g']
else
  common_c_args += ['-O2']
  common_link_args = []
endif

omp_dep = dependency('openmp', required: get_option('openmp'))

# --- Install pure python package tree ---
# After `git mv src assimulo`, this installs assimulo/** into site-packages/assimulo/**
install_subdir('src/assimulo', install_dir: py.get_install_dir())

# --- Helper: find include/lib dirs from a prefix or from standard locations ---
sundials_prefix = get_option('sundials_prefix')
superlu_prefix  = get_option('superlu_prefix')

default_inc_candidates = ['/usr/include', '/usr/local/include']
default_lib_candidates = ['/usr/lib', '/usr/lib64', '/usr/local/lib', '/usr/lib/x86_64-linux-gnu', '/usr/local/lib/x86_64-linux-gnu']

sundials_inc_candidates = []
sundials_lib_candidates = []
if sundials_prefix != ''
  sundials_inc_candidates += [join_paths(sundials_prefix, 'include')]
  foreach d : ['lib', 'lib64', 'lib/x86_64-linux-gnu']
    sundials_lib_candidates += [join_paths(sundials_prefix, d)]
  endforeach
else
  sundials_inc_candidates += default_inc_candidates
  sundials_lib_candidates += default_lib_candidates
endif

sundials_incdir = ''
foreach d : sundials_inc_candidates
  if fs.is_file(join_paths(d, 'cvodes', 'cvodes.h'))
    sundials_incdir = d
    break
  endif
endforeach
if sundials_incdir == ''
  error('SUNDIALS not found: could not locate cvodes/cvodes.h. Set -Dsundials_prefix=...')
endif

sundials_inc_dir = include_directories(sundials_incdir)

sundials_libdirs = []
foreach d : sundials_lib_candidates
  if fs.is_dir(d)
    sundials_libdirs += d
  endif
endforeach

# SUNDIALS 2.7.0 libraries
sundials_cvodes_libs = [
  cc.find_library('sundials_cvodes',     dirs: sundials_libdirs, static: true, required: true),
  cc.find_library('sundials_idas',       dirs: sundials_libdirs, static: true, required: true),
  cc.find_library('sundials_nvecserial', dirs: sundials_libdirs, static: true, required: true),
]

sundials_kinsol_libs = [
  cc.find_library('sundials_kinsol',     dirs: sundials_libdirs, static: true, required: true),
  cc.find_library('sundials_nvecserial', dirs: sundials_libdirs, static: true, required: true),
]

# --- SuperLU detection (optional; used by radau5ode + possibly sundials superlu solver) ---
with_superlu = false
superlu_incdir = ''
superlu_libdirs = []

if superlu_prefix != ''
  foreach d : [join_paths(superlu_prefix, 'include'), join_paths(superlu_prefix, 'SRC')]
    if fs.is_file(join_paths(d, 'supermatrix.h'))
      superlu_incdir = d
      break
    endif
  endforeach

  foreach d : ['lib', 'lib64', 'lib/x86_64-linux-gnu']
    p = join_paths(superlu_prefix, d)
    if fs.is_dir(p)
      superlu_libdirs += p
    endif
  endforeach

  if superlu_incdir != '' and superlu_libdirs.length() > 0
    with_superlu = true
  endif
endif

# When SUNDIALS is compiled with SuperLU the solver .a files reference SuperLU
# symbols, so the Python extensions must also link against superlu_mt and blas.
sundials_superlu_deps = []
if with_superlu
  sundials_superlu_deps += [
    cc.find_library('superlu_mt_OPENMP', dirs: superlu_libdirs, static: true, required: true),
    cc.find_library('blas', dirs: default_lib_candidates, static: true, required: true),
  ]
endif

# --- Cython targets ---
cython_include_dirs = [
  '-I', meson.current_build_dir(),
  '-I', join_paths(meson.current_source_dir(), 'src/assimulo'),
  '-I', join_paths(meson.current_source_dir(), 'src/assimulo/lib'),
]
cython_common_args = ['-3', '-X', 'language_level=3str'] + cython_include_dirs

# Core modules in assimulo/
py.extension_module(
  'explicit_ode',
  sources: ['src/assimulo/explicit_ode.pyx', 'src/assimulo/ode_event_locator.c'],
  subdir: 'assimulo',
  include_directories: include_directories('src/assimulo'),
  c_args: common_c_args,
  dependencies: [],
  install: true
)

foreach mod : ['algebraic', 'implicit_ode', 'ode', 'problem', 'special_systems', 'support']
  py.extension_module(
    mod,
    sources: ['src/assimulo/' + mod + '.pyx'],
    subdir: 'assimulo',
    include_directories: include_directories('src/assimulo'),
    c_args: common_c_args,
    dependencies: [],
    install: true
  )
endforeach

# Euler solver
py.extension_module(
  'euler',
  sources: ['src/assimulo/solvers/euler.pyx'],
  subdir: 'assimulo/solvers',
  include_directories: include_directories('src/assimulo', 'src/assimulo/solvers'),
  c_args: common_c_args,
  dependencies: [],
  install: true
)

sundials_conf = configuration_data()
sundials_conf.set('SUNDIALS_WITH_SUPERLU', with_superlu ? 'True' : 'False')

sundials_pxi = configure_file(
  input: 'src/assimulo/sundials.pxi.in',
  output: 'sundials.pxi',
  configuration: sundials_conf,
  install: false,
)

py.extension_module(
  'sundials',
  sources: ['src/assimulo/solvers/sundials.pyx', sundials_pxi],
  subdir: 'assimulo/solvers',
  include_directories: [include_directories('src/assimulo', 'src/assimulo/lib'), sundials_inc_dir],
  c_args: common_c_args,
  dependencies: [omp_dep] + sundials_cvodes_libs + sundials_superlu_deps,
  cython_args: cython_common_args,
  install: true
)

py.extension_module(
  'kinsol',
  sources: ['src/assimulo/solvers/kinsol.pyx', sundials_pxi],
  subdir: 'assimulo/solvers',
  include_directories: [include_directories('src/assimulo', 'src/assimulo/lib'), sundials_inc_dir],
  c_args: common_c_args,
  dependencies: [omp_dep] + sundials_kinsol_libs + sundials_superlu_deps,
  cython_args: cython_common_args,
  install: true
)

# radau5ode (Cython + C sources, optional SuperLU)
radau5_inc_dirs = [
  include_directories('src/assimulo', 'src/assimulo/lib'),
  sundials_inc_dir,
  include_directories('thirdparty/radau5'),
]
radau5_c_args = common_c_args
radau5_deps = [omp_dep, cc.find_library('m', required: true)]

radau5_extra_sources = [
  'thirdparty/radau5/radau5.c',
  'thirdparty/radau5/radau5_io.c',
]

if with_superlu
  radau5_c_args += ['-D__RADAU5_WITH_SUPERLU']
  radau5_inc_dirs += [include_directories(superlu_incdir)]
  radau5_extra_sources += [
    'thirdparty/radau5/superlu_double.c',
    'thirdparty/radau5/superlu_complex.c',
    'thirdparty/radau5/superlu_util.c',
  ]

  # Try to find SuperLU_MT and BLAS (and optionally a blas_OPENMP compatibility lib)
  superlu_mt = cc.find_library('superlu_mt_OPENMP', dirs: superlu_libdirs, static: true, required: true)
  radau5_deps += [superlu_mt]

  blas_openmp = cc.find_library('blas_OPENMP', dirs: default_lib_candidates, static: true, required: false)
  blas = cc.find_library('blas', dirs: default_lib_candidates, static: true, required: true)
  if blas_openmp.found()
    radau5_deps += [blas_openmp]
  endif
  radau5_deps += [blas]

  # gomp is typically needed when linking OpenMP with gcc
  gomp = cc.find_library('gomp', required: false)
  if gomp.found()
    radau5_deps += [gomp]
  endif
endif

py.extension_module(
  'radau5ode',
  sources: ['thirdparty/radau5/radau5ode.pyx'] + radau5_extra_sources,
  subdir: 'assimulo/lib',
  include_directories: radau5_inc_dirs,
  c_args: radau5_c_args,
  dependencies: radau5_deps,
  cython_args: cython_common_args,
  install: true
)

fortran_solvers = [
  {
    'name': 'dopri5',
    'subdir': 'hairer',
    'sources': ['dopri5.f', 'dopri5.pyf'],
  },
  {
    'name': 'rodas',
    'subdir': 'hairer',
    'sources': ['rodas_decsol.f', 'rodas_decsol.pyf'],
  },
  {
    'name': 'radau5',
    'subdir': 'hairer',
    'sources': ['radau_decsol.pyf', 'radau_decsol.f'],
  },
  {
    'name': 'radar5',
    'subdir': 'hairer',
    'sources': [
      'contr5.f90', 'radar5_int.f90', 'radar5.f90', 'dontr5.f90',
      'decsol.f90', 'dc_decdel.f90', 'radar5.pyf',
    ],
  },
  {
    'name': 'odepack',
    'subdir': 'odepack',
    'sources': ['opkdmain.f', 'opkda1.f', 'opkda2.f', 'odepack_aux.f90', 'odepack.pyf'],
  },
  {
    'name': 'odassl',
    'subdir': 'odassl',
    'sources': [
      'odassl.pyf', 'odassl.f', 'odastp.f', 'odacor.f', 'odajac.f', 'd1mach.f',
      'daxpy.f', 'ddanrm.f',  'ddatrp.f', 'ddot.f', 'ddwats.f', 'dgefa.f', 'dgesl.f',
      'dscal.f', 'idamax.f', 'xerrwv.f',
    ],
  },
  {
    'name': 'dasp3dp',
    'subdir': 'dasp3',
    'sources': [
      'dasp3dp.pyf', 'DASP3.f', 'ANORM.f', 'CTRACT.f', 'DECOMP.f', 'HMAX.f', 'INIVAL.f',
      'JACEST.f', 'PDERIV.f', 'PREPOL.f', 'SOLVE.f', 'SPAPAT.f',
    ],
    'extra_args': [],
  },
  {
    'name': 'glimda',
    'subdir': 'glimda',
    'sources': ['glimda_complete.pyf', 'glimda_complete.f'],
    'extra_args': ['--dep', 'blas', '--dep', 'lapack'],
  }
]

# --- f2py / Fortran solver modules (first attempt) ---
# This is intentionally "best effort" in the first conversion pass; can be toggled off.
if get_option('enable_fortran')
  ext_suffix = run_command(
    py,
    ['-c', 'import sysconfig; print(sysconfig.get_config_var("EXT_SUFFIX"))'],
    check: true
  ).stdout().strip()

  foreach solver : fortran_solvers

    f2py_fc_args = ['--fcompiler=gnu95', '--f77flags=--std=legacy'] + solver.get('extra_args', [])

    solver_srcs = []
    solver_src_dir = join_paths(meson.current_source_dir(), 'thirdparty', solver['subdir'])
    foreach f : solver['sources']
      solver_srcs += join_paths(solver_src_dir, f)
    endforeach

    solver_name = solver['name']
    custom_target(
      'f2py_' + solver_name,
      output: solver_name + ext_suffix,
      install_dir: join_paths(py.get_install_dir(), 'assimulo/lib'),
      install: true,
      command: [
        py, '-m', 'numpy.f2py', '-c', '-m', solver_name,
      ] + solver_srcs + f2py_fc_args,
      console: true,
      build_by_default: true
    )
  endforeach
endif
