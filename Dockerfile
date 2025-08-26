FROM ubuntu:24.04

# Install system dependencies including Erlang, OCaml tools, and build essentials
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y opam build-essential git make m4 pkg-config libgmp-dev python3 z3 libz3-4 software-properties-common && \
    add-apt-repository ppa:rabbitmq/rabbitmq-erlang && \
    apt-get update && \
    apt-get install -y erlang && \
    rm -rf /var/lib/apt/lists/*

# Create developer user and set up working directory
RUN useradd -m -s /bin/bash developer
USER developer
WORKDIR /home/developer

# Initialize opam (OCaml package manager) and install development tools
RUN opam init -y --disable-sandboxing
RUN eval $(opam env --switch=default) && \
    opam install -y ocaml-lsp-server odoc ocamlformat utop
RUN eval $(opam env --switch=default) && \
    opam install -y ppx_import visitors z3 bag cmdliner

# Clone and build mbcheck tool (required dependency for paterl)
RUN mkdir Development
WORKDIR /home/developer/Development
RUN eval $(opam env --switch=default) && \
    git clone https://github.com/SimonJF/mbcheck.git && \
    cd mbcheck && \
    git checkout paterl-experiments && \
    make && \
    test -f mbcheck || (echo "ERROR: mbcheck binary not found!" && exit 1)

# Clone paterl repository and set up working directory
RUN git clone https://github.com/duncanatt/paterl.git
WORKDIR /home/developer/Development/paterl

# Configure paterl to use mbcheck, build the project, and run verification test
RUN sed -i 's|^-define(EXEC,.*| -define(EXEC, "/home/developer/Development/mbcheck/mbcheck").|' src/paterl.erl && \
    make && \
    echo "Testing paterl installation..." && \
    ./src/paterl src/examples/erlang/codebeam/id_server_demo.erl -v all -I include && \
    echo "SUCCESS: Paterl test completed!"

# Set up environment variables and aliases for easy access to paterl
RUN echo 'export PATH=/home/developer/Development/paterl/src:$PATH' >> /home/developer/.bashrc && \
    echo 'alias paterl="/home/developer/Development/paterl/src/paterl"' >> /home/developer/.bashrc && \
    echo 'echo "Paterl is ready! Try: paterl src/examples/erlang/codebeam/id_server_demo.erl -v all -I include"' >> /home/developer/.bashrc

# Start container with bash shell
ENTRYPOINT ["bash"]