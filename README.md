# server

Proxmox VE上のNixOS VM `incus-host` でIncusを動かし、その中のNixOSコンテナとして自宅サーバー群を配信する。

```text
inventory.nix  ホストとゲストの唯一の定義（IP、資源、公開ポート、ディスク）
flake.nix      inventoryからNixOS構成とOpenTofu変数を生成
hosts/         incus-host のNixOS構成
guests/        ゲストごとのNixOS構成
modules/       共通・ホスト・ゲストの基盤
tofu/          Incusのstorage、network、ACL、forward、instance
scripts/       justから呼ぶ処理
secrets/       sops暗号文
```

`inventory.nix` の `guests.<name>.enable` が、OpenTofuでインスタンスを作るかどうかと `just deploy` の対象を決める。公開ポートはホストの全アドレス（LANとtailnet）でIncus proxy deviceが待ち受け、ゲストの同じポートへ中継する。ゲスト側では接続元がlocalhostに見える。ゲストにSSHは無く、ホストから `incus exec` で操作する。

## 日常の流れ

incus-hostにこのリポジトリをcloneしておき、そこで実行する。

```bash
git pull
just check        # Nix評価、OpenTofu validate/test、shellcheck
just switch-host  # ホスト自体の構成を反映
just apply        # inventory.nixからtfvarsを生成してIncusへ適用
just deploy       # 有効な全ゲストをホストでビルドし、差分のstore pathだけ送って切り替え
just deploy web-server
```

`just check` は管理端末（macOS）でも `nix develop -c just check` で実行できる。OpenTofuのstateはホストの `tofu/terraform.tfstate` に置く（Git管理外）。

## 初回構築

1. PVEでテンプレート9001（NixOS cloud-init）をcloneし、btrfs用の2台目のvirtio diskを追加する。
2. VM上で2台目のdiskを `mkfs.btrfs -L incus` し、このリポジトリをcloneして `just switch-host` を実行する。
3. `sudo tailscale up` でtailnetへ参加する。
4. `just apply` でbridge、storage pool、forward、インスタンスを作成し、`just deploy` でNixOS構成を適用する。
5. sopsを使うゲストにはage鍵を渡す: `just guest-key web-server < key.txt`（鍵の受け渡しは端末上で行い、ログに残さない）。

## secret

`.sops.yaml` の受信者は、管理者鍵とゲストごとの鍵。ゲストの鍵は `/var/lib/sops-nix/key.txt` に置く。web-serverは旧VMの鍵を引き継ぐので、既存の暗号文をそのまま復号できる。
