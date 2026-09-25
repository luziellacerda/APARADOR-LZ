# Releases e compilação automática

[Voltar ao projeto](../README.md) · [Instalar e usar](TUTORIAL.md)

O fluxo [Compilar e publicar Windows offline](../.github/workflows/release.yml) compila o **LZ Games 1.5.0** no GitHub Actions. O instalador completo inclui FFmpeg e ffprobe: o aplicativo não precisa buscar esses componentes na primeira abertura e processa os vídeos localmente.

**Disponibilidade:** consulte [Releases](https://github.com/luziellacerda/APARADOR-LZ/releases) e o resultado da execução em [Actions](https://github.com/luziellacerda/APARADOR-LZ/actions). A existência do código ou de uma tag não significa que o instalador terminou de compilar. Uma versão só é publicada pelo fluxo após as verificações obrigatórias passarem.

## Para baixar e instalar

Na release da versão desejada, abra **Assets** e baixe `LZGames-Aparador-1.5.0-Setup.exe`. Não escolha **Source code (zip)** para instalar: esse arquivo é para desenvolvimento.

O instalador é para Windows 10/11 x64 Intel/AMD. .NET Framework 4.8 e Windows PowerShell 5.1 continuam sendo requisitos locais; não estão embutidos no pacote. O instalador verifica a presença deles e não faz downloads automáticos. Veja [TUTORIAL.md](TUTORIAL.md).

Os executáveis não recebem assinatura Authenticode automaticamente. O Windows pode mostrar **editor desconhecido**. Confira a origem; não desative as proteções do sistema para abrir o programa.

## Arquivos de cada release

| Arquivo | Finalidade |
| --- | --- |
| `LZGames-Aparador-1.5.0-Setup.exe` | Instalador completo com programa, componentes de vídeo, atalhos e desinstalador. |
| `FFmpeg-corresponding-source.tar.xz` | Fontes correspondentes dos componentes de vídeo e materiais usados na compilação, para consulta e reconstrução. Não é necessário extraí-lo para usar o programa. |
| `APARADOR-LZ-1.5.0-source.zip` | Código da aplicação arquivado diretamente do commit usado no build. |
| `RELEASE-MANIFEST.json` | Commit, execução do Actions, contagem das verificações, tamanhos e hashes dos arquivos. Não contém caminhos pessoais nem vídeos de teste. |
| `SHA256SUMS.txt` | SHA256 dos quatro arquivos acima. |

Para conferir o instalador baixado no Windows PowerShell:

```powershell
Get-FileHash -Algorithm SHA256 -LiteralPath '.\LZGames-Aparador-1.5.0-Setup.exe'
```

Compare o resultado com a linha correspondente de `SHA256SUMS.txt`, baixado da **mesma release**. A comparação detecta diferenças no arquivo; não é uma assinatura digital nem uma auditoria de segurança.

## O que o Actions executa

1. Em Ubuntu 24.04, compila FFmpeg, x264 e x265 a partir de revisões/fontes fixadas em `ci/Build-FFmpeg.sh`, gerando executáveis Windows x64 e o arquivo de fontes correspondentes.
2. Em Windows Server 2022, compila o aplicativo pelo Windows PowerShell 5.1 e pelo compilador do .NET Framework. Usa NSIS 3.10 do runner, conferindo a versão; o NSIS 3.12 utilizado no build local anterior continua sendo uma alternativa local.
3. Executa o autoteste do EXE compilado, processamento real de mídia sintética e instalação/reinstalação/desinstalação da variante isolada **TESTE**. Os testes de CI avaliam essa compilação; os resultados históricos locais não são reutilizados como aprovação.
4. `ci/Prepare-Release.ps1` exige relatórios aprovados e verifica se os hashes correspondem exatamente aos arquivos do build. Recusa teste sem reinstalação, versão incompatível, alteração de payload e saída que já existe.
5. Um job separado publica somente a lista de arquivos acima, após a aprovação do build. A variante **TESTE**, vídeos sintéticos, diretório de trabalho, credenciais e relatórios brutos não são anexados à release.

O fluxo não faz upload dos vídeos do usuário. O build roda em máquinas do GitHub; o processamento no programa instalado é local. A automação não é certificação de todos os formatos, tamanhos de tela ou versões do Windows. Consulte [TESTES.md](TESTES.md).

## Criar a versão 1.5.0

A versão 1.5.0 corresponde à interface minimalista e à correção de repintura. Consulte Releases para confirmar a publicação; a existência do código não significa que a compilação terminou. Não recrie nem sobrescreva uma tag já existente.

Para o mantenedor, após revisar e enviar o commit com o código e o workflow:

```powershell
git tag -a v1.5.0 -m 'LZ Games 1.5.0'
git push origin v1.5.0
```

Esse exemplo é apenas para uma tag **ainda inexistente**. Não sobrescreva tags ou arquivos de uma release publicada. Corrija problemas em um novo commit e utilize uma nova versão quando necessário.

Acompanhe a execução em **Actions**. Se alguma etapa falhar, o fluxo não deve publicar um instalador como aprovado: leia os logs, corrija a causa e repita a validação. A opção manual **Run workflow** serve para executar o fluxo no ref selecionado; a publicação é reservada a uma tag de versão válida.

Nesta base, `1.5.0` aparece no aplicativo, nos empacotadores e nos testes. Para lançar outra versão, atualize esses locais de forma consistente e valide novamente. Não basta mudar o nome da tag.

## Reprodução local e limites

[COMPILAR.md](COMPILAR.md) descreve a compilação local. Para preparar os arquivos finais, além do build é preciso ter os componentes construídos em `ci-out`, o arquivo de fontes correspondentes e os relatórios aprovados da execução atual:

```powershell
powershell.exe -NoProfile -File .\ci\Prepare-Release.ps1 `
  -BuildRoot .\builds\ci `
  -DependencyRoot .\ci-out `
  -OutputDirectory .\release-out `
  -MediaReportPath '.\media-tests\IDENTIFICADOR\result.json' `
  -InstallerReportPath '.\tests\runs\IDENTIFICADOR\installer-test-result.json'
```

Troque os identificadores pelos caminhos emitidos pelos testes. Não use os relatórios de outra compilação. O código versionado deve corresponder a um commit sem alterações locais antes desse empacotamento. O script prepara arquivos; não os envia automaticamente ao GitHub.

As versões de dependências e suas fontes são fixadas, mas a imagem do runner e o compilador do sistema podem receber atualizações. Não se promete reprodução byte a byte. O hash válido é o da execução que produziu a release em questão. Os materiais de terceiros e suas licenças acompanham a distribuição; isso não atribui uma licença nova ao código da aplicação. Leia [DEPENDENCIAS.md](DEPENDENCIAS.md).
