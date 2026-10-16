# ローカルアプリの署名と権限維持

## 問題と対応

ad hoc署名ではdesignated requirementがバイナリのcdhashに固定される。実装更新でハッシュが変わるため、macOSのプライバシー許可が以前のアプリと対応しなくなる可能性がある。ウィンドウマネージャー画面の常時表示では解決しない。

Resources/Signing.xcconfigをXcodeのDebug／Releaseで読み込む。このMacでは既存のApple Development証明書を使用する。選択値はGit除外の`.local-signing.xcconfig`に以下の形式で置き、プロジェクト再生成時も保持する。

```xcconfig
MYTOOLBOX_SIGNING_IDENTITY = 証明書のSHA-1フィンガープリント
```

秘密鍵は既存キーチェーン内で署名に使い、ファイルへ書き出さない。新しい証明書作成、信頼ルート追加、OSの許可自動変更は行わない。

## 更新時

同じ証明書・bundle IDでビルドし、`codesign -d -r-`でdesignated requirementを照合する。証明書署名のインストール済みアプリがある場合、標準Fullはad hocへの逆戻りを拒否する。fresh checkoutはad hocでビルドできるが、権限維持が必要な通常利用先へ配置する前にローカル設定を復元する。

初めてad hocから証明書署名へ変更する際は、ユーザーがアクセシビリティを許可し直す必要がある。同じ署名での更新後に権限が維持されるかは実機で確認する。証明書の期限切れ・更新、署名方式の変更時は再確認が必要。Apple Development署名はローカル開発用で、Developer ID配布・公証の代替ではない。

## 検証

標準Fast／Full、test_verify.pyのad hoc逆戻り拒否テスト。さらに変更した実行ファイルを同じ証明書で署名し、更新前のdesignated requirementで検証する。これはコードの同一性判定の検証であり、実機TCC許可維持の成功とは区別する。

参考：[Apple TN3127](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements)、[Appleコード署名ガイド](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/Procedures/Procedures.html)。
