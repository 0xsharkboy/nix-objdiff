{ runCommand, stdenv }:
runCommand "objdiff-fixture" { nativeBuildInputs = [ stdenv.cc ]; } ''
  mkdir -p $out
  cc -c -O0 -g ${./fixture.c} -o $out/target.o
  cc -c -O0 -g -DVALUE=9 ${./fixture.c} -o $out/changed.o
  cp $out/target.o $out/base.o
  cat > $out/objdiff.json <<'EOF'
  {
    "build_base": false,
    "build_target": false,
    "units": [{"name": "example", "target_path": "target.o", "base_path": "base.o"}]
  }
  EOF
''
