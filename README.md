
## **Setup**

아래 스크립트의 실행은 기본 환경을 구성한다.

```shell
source scripts/setup_env.sh
```

> [!NOTE]
> 위 셋업 스크립트는 내부적으로 Ignite CLI의 릴리즈를 다운받는다.  
> 하지만, [Ignite CLI의 GitHub 레포](https://github.com/ignite/cli.git)를 클론한 뒤 버전 tag를 이용해 `checkout`(내지 `switch`)를 수행할 수도 있다. 다만, 이 경우 2GB가 넘는 저장 공간을 차지하는 반면, 각각의 릴리즈 크기는 <30MB 이다.

### **버전 호환 표**

|   Ignite CLI    | Cosmos SDK | *remark* |
| :-------------: | :--------: | :------- |
| v28.6.1 ~ .7.0  |  v0.50.11  | vulnerability: [ASA-2025-003](https://github.com/cosmos/cosmos-sdk/security/advisories/GHSA-x5vx-95h7-rv4p)                    |
| v28.8.0 ~ .8.1  |  v0.50.12  | fix: ASA-2025-003,<br>vulnerability: [ISA-2025-002](https://github.com/cosmos/cosmos-sdk/security/advisories/GHSA-47ww-ff84-4jrg) |
| v28.8.2 ~ .10.0 |  v0.50.13  | fix: ISA-2025-002                                                                                                              |



## **체인 데몬 구동 방법**

```shell
cd scaffolds/〈체인_디렉토리〉  # cd scaffolds/csdk-A
```

```shell
ignite chain serve --reset-once -v  # 로그 출력
```

## **취약점 재현**

### **#1**
`csdk-A` 체인의 데몬을 실행한 뒤, 다른 쉘에서 다음을 실행한다.

```shell
./scripts/reproduce_1.sh csdk-Ad
```

### **#2**
`csdk-B` 체인의 데몬을 실행한 뒤, 다른 쉘에서 다음을 실행한다.

```shell
./scripts/reproduce_2.sh csdk-Bd
```

