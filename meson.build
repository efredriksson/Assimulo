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
if cc.get_argument_syntax() == 'msvc'
  common_c_args = ['-I' + numpy_inc]
  if get_option('debug')
    common_c_args += ['/Zi']
    common_link_args = ['/DEBUG']
  else
    common_c_args += ['/O2']
    common_link_args = []
  endif
else
  common_c_args = ['-fno-strict-aliasing', '-I' + numpy_inc]
  if get_option('debug')
    common_c_args += ['-g']
    common_link_args = ['-g']
  else
    common_c_args += ['-O2']
    common_link_args = []
  endif
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
if host_machine.system() == 'windows'
  default_lib_candidates += ['C:/deps/lib']
endif

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

# SUNDIALS 2.7.0 libraries — prefer shared so extensions don't duplicate the code
sundials_cvodes_libs = [
  cc.find_library('sundials_cvodes',     dirs: sundials_libdirs, required: true),
  cc.find_library('sundials_idas',       dirs: sundials_libdirs, required: true),
  cc.find_library('sundials_nvecserial', dirs: sundials_libdirs, required: true),
]

sundials_kinsol_libs = [
  cc.find_library('sundials_kinsol',     dirs: sundials_libdirs, required: true),
  cc.find_library('sundials_nvecserial', dirs: sundials_libdirs, required: true),
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

# With shared SUNDIALS libs, SuperLU and BLAS are embedded in the shared libs
# themselves (via target_link_libraries in the Dockerfiles), so extensions do
# not need to link against them separately.

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
  dependencies: [omp_dep] + sundials_cvodes_libs,
  cython_args: cython_common_args,
  install: true
)

py.extension_module(
  'kinsol',
  sources: ['src/assimulo/solvers/kinsol.pyx', sundials_pxi],
  subdir: 'assimulo/solvers',
  include_directories: [include_directories('src/assimulo', 'src/assimulo/lib'), sundials_inc_dir],
  c_args: common_c_args,
  dependencies: [omp_dep] + sundials_kinsol_libs,
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
libm = cc.find_library('m', required: host_machine.system() != 'windows')
radau5_deps = [omp_dep, libm]

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

f2py_src = run_command(
  py,
  ['-c', 'import numpy.f2py, os; print(os.path.join(os.path.dirname(numpy.f2py.__file__), "src"))'],
  check: true
).stdout().strip()
fortranobject_c = join_paths(f2py_src, 'fortranobject.c')

# On Windows, BLAS/LAPACK are statically linked (no DLL bundled in the wheel).
# Default 'reference': small reference impl (libblas.a + liblapack.a from mingw lapack package).
# Optional 'openblas': fast but adds ~30 MB to glimda.pyd; also requires OpenMP.
# On Linux, link dynamically against the system-provided shared libraries.
if host_machine.system() == 'windows'
  if get_option('windows_blas') == 'openblas'
    blas_dep    = cc.find_library('openblas', dirs: default_lib_candidates, static: true, required: true)
    glimda_deps = [blas_dep, omp_dep]
  else
    blas_dep    = cc.find_library('blas',   dirs: default_lib_candidates, static: true, required: true)
    lapack_dep  = cc.find_library('lapack', dirs: default_lib_candidates, static: true, required: true)
    glimda_deps = [blas_dep, lapack_dep]
  endif
else
  blas_dep    = cc.find_library('blas',   dirs: default_lib_candidates, required: true)
  lapack_dep  = cc.find_library('lapack', dirs: default_lib_candidates, required: true)
  glimda_deps = [blas_dep, lapack_dep]
endif
fortran_solvers = [
  {
    'name':         'dopri5',
    'pyf':          files('thirdparty/hairer/dopri5.pyf'),
    'fortran_srcs': files('thirdparty/hairer/dopri5.f'),
    'outputs':      ['module.c', '-f2pywrappers.f'],
  },
  {
    'name':         'rodas',
    'pyf':          files('thirdparty/hairer/rodas_decsol.pyf'),
    'fortran_srcs': files('thirdparty/hairer/rodas_decsol.f'),
    'outputs':      ['module.c', '-f2pywrappers.f'],
  },
  {
    'name':         'radau5',
    'pyf':          files('thirdparty/hairer/radau_decsol.pyf'),
    'fortran_srcs': files('thirdparty/hairer/radau_decsol.f'),
    'outputs':      ['module.c', '-f2pywrappers.f'],
  },
  {
    'name':         'radar5',
    'pyf':          files('thirdparty/hairer/radar5.pyf'),
    'fortran_srcs': files(
      'thirdparty/hairer/contr5.f90', 'thirdparty/hairer/radar5_int.f90',
      'thirdparty/hairer/radar5.f90', 'thirdparty/hairer/dontr5.f90',
      'thirdparty/hairer/decsol.f90', 'thirdparty/hairer/dc_decdel.f90',
    ),
    'outputs':      ['module.c', '-f2pywrappers.f', '-f2pywrappers2.f90'],
  },
  {
    'name':         'odepack',
    'pyf':          files('thirdparty/odepack/odepack.pyf'),
    'fortran_srcs': files(
      'thirdparty/odepack/opkdmain.f', 'thirdparty/odepack/opkda1.f',
      'thirdparty/odepack/opkda2.f',   'thirdparty/odepack/odepack_aux.f90',
    ),
    'outputs':      ['module.c', '-f2pywrappers.f'],
  },
  {
    'name':         'odassl',
    'pyf':          files('thirdparty/odassl/odassl.pyf'),
    'fortran_srcs': files(
      'thirdparty/odassl/odassl.f',  'thirdparty/odassl/odastp.f',
      'thirdparty/odassl/odacor.f',  'thirdparty/odassl/odajac.f',
      'thirdparty/odassl/d1mach.f',  'thirdparty/odassl/daxpy.f',
      'thirdparty/odassl/ddanrm.f',  'thirdparty/odassl/ddatrp.f',
      'thirdparty/odassl/ddot.f',    'thirdparty/odassl/ddwats.f',
      'thirdparty/odassl/dgefa.f',   'thirdparty/odassl/dgesl.f',
      'thirdparty/odassl/dscal.f',   'thirdparty/odassl/idamax.f',
      'thirdparty/odassl/xerrwv.f',
    ),
    'outputs':      ['module.c', '-f2pywrappers.f'],
  },
  {
    'name':         'dasp3dp',
    'pyf':          files('thirdparty/dasp3/dasp3dp.pyf'),
    'fortran_srcs': files(
      'thirdparty/dasp3/DASP3.f',   'thirdparty/dasp3/ANORM.f',
      'thirdparty/dasp3/CTRACT.f',  'thirdparty/dasp3/DECOMP.f',
      'thirdparty/dasp3/HMAX.f',    'thirdparty/dasp3/INIVAL.f',
      'thirdparty/dasp3/JACEST.f',  'thirdparty/dasp3/PDERIV.f',
      'thirdparty/dasp3/PREPOL.f',  'thirdparty/dasp3/SOLVE.f',
      'thirdparty/dasp3/SPAPAT.f',
    ),
    'outputs':      ['module.c', '-f2pywrappers.f'],
  },
  {
    'name':         'glimda',
    'pyf':          files('thirdparty/glimda/glimda_complete.pyf'),
    'fortran_srcs': files('thirdparty/glimda/glimda_complete.f'),
    'outputs':      ['module.c', '-f2pywrappers.f'],
    'extra_deps':   glimda_deps,
  },
]

# --- f2py / Fortran solver modules ---
if get_option('enable_fortran')
  foreach solver : fortran_solvers
    solver_name  = solver['name']
    fortran_srcs = solver['fortran_srcs']

    solver_outputs = []
    foreach suf : solver['outputs']
      solver_outputs += solver_name + suf
    endforeach

    wrappers = custom_target(
      'f2py_wrap_' + solver_name,
      input:   solver['pyf'],
      output:  solver_outputs,
      command: [py,
                join_paths(meson.current_source_dir(), 'tools', 'f2py_wrapper.py'),
                '@OUTDIR@', solver_name, '@INPUT@'],
      build_by_default: false,
    )

    # Compile Fortran sources as a static library first so that any Fortran
    # module files (.mod) are generated before the f2py wrapper files are
    # compiled (e.g. radar5-f2pywrappers2.f90 uses the ip_array module from
    # radar5.f90, and meson does not scan custom_target outputs for 'use').
    solver_lib = static_library(
      solver_name + '_impl',
      sources:      fortran_srcs,
      fortran_args: ['-std=legacy'],
      pic:          true,
      install:      false,
    )

    py.extension_module(
      solver_name,
      sources:             [wrappers] + [fortranobject_c],
      subdir:              'assimulo/lib',
      include_directories: include_directories('src/assimulo'),
      c_args:              common_c_args + ['-I' + f2py_src],
      fortran_args:        ['-std=legacy'],
      dependencies:        solver.get('extra_deps', []),
      link_with:           solver_lib,
      install:             true,
    )
  endforeach
endif
