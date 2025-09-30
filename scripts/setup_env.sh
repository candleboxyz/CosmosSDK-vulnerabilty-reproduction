export PATH=$(go env GOPATH)/bin:$PATH
WORK_DIR=$(pwd)

wget -O v28.6.1.zip https://github.com/ignite/cli/archive/refs/tags/v28.6.1.zip  # Cosmos SDK v0.50.11
wget -O v28.8.1.zip https://github.com/ignite/cli/archive/refs/tags/v28.8.1.zip  # Cosmos SDK v0.50.12
wget -O v28.8.2.zip https://github.com/ignite/cli/archive/refs/tags/v28.8.2.zip  # Cosmos SDK v0.50.13

for f in *.zip; do [ -e "$f" ] || continue; unzip -o "$f"; done  # unzip

cd "cli-28.6.1"
make install  # install dir: `go env GOPATH` → ~/go/bin/
ignite scaffold chain csdk-A --path $WORK_DIR/scaffolds/csdk-A

cd "../cli-28.8.1"
make install
ignite scaffold chain csdk-B --path $WORK_DIR/scaffolds/csdk-B

cd "../cli-28.8.2"
make install
ignite scaffold chain csdk-C --path $WORK_DIR/scaffolds/csdk-C

cd $WORK_DIR

cp json_template/members.json .
cp json_template/policy.json .
cp json_template/proposal.json .

chmod +x scripts/reproduce_1.sh
chmod +x scripts/reproduce_2.sh