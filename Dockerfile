# Build stage with Spack pre-installed and ready to be used
FROM spack/ubuntu-jammy:develop as builder


# What we want to install and how we want to install it
# is specified in a manifest file (spack.yaml)
RUN mkdir -p /opt/spack-environment && \
set -o noclobber \
&&  (echo spack: \
&&   echo '  specs:' \
&&   echo '  - gmake @4.3' \
&&   echo '  - libfabric fabrics=sockets,tcp,udp,psm2,verbs' \
&&   echo '  - gromacs@2023%gcc +plumed +mpi +openmp +cuda ^openmpi@4.1.6+cuda ^cuda ^slurm@23-02-7-1' \
&&   echo '    +pmix ^ucx' \
&&   echo '  packages:' \
&&   echo '    openmpi:' \
&&   echo '      require: +pmi+legacylaunchers fabrics=ucx schedulers=slurm' \
&&   echo '    ucx:' \
&&   echo '      require: +thread_multiple +cma +rc +ud +dc +mlx5_dv +ib_hw_tm +dm' \
&&   echo '  concretizer:' \
&&   echo '    unify: true' \
&&   echo '  config:' \
&&   echo '    install_tree: /opt/software' \
&&   echo '  view: /opt/views/view') > /opt/spack-environment/spack.yaml

# Install the software, remove unnecessary deps
RUN source /opt/spack/share/spack/setup-env.sh && cd /opt/spack-environment && spack env activate . && spack install --fail-fast && spack gc -y

# Modifications to the environment that are necessary to run
RUN cd /opt/spack-environment && \
    spack env activate --sh -d . > activate.sh


# Bare OS image to run the installed executables
FROM ubuntu:22.04

COPY --from=builder /opt/spack-environment /opt/spack-environment
COPY --from=builder /opt/software /opt/software

# paths.view is a symlink, so copy the parent to avoid dereferencing and duplicating it
COPY --from=builder /opt/views /opt/views

RUN { \
      echo '#!/bin/sh' \
      && echo '.' /opt/spack-environment/activate.sh \
      && echo 'exec "$@"'; \
    } > /entrypoint.sh \
&& chmod a+x /entrypoint.sh \
&& ln -s /opt/views/view /opt/view


RUN apt-get -yqq update && apt-get -yqq upgrade \
 && apt-get -yqq install gfortran \
 && rm -rf /var/lib/apt/lists/*
LABEL "app"="gromcas"
LABEL "mpi"="openmpi"
ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "/bin/bash" ]

