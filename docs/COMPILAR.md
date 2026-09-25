# Compilar o aplicativo e o instalador

Este repositório contém o código do LZ Games 1.3.0, os testes e os scripts de empacotamento. Os executáveis e os instaladores não são versionados. Para gerar tudo pelo GitHub Actions, consulte [RELEASE.md](RELEASE.md). Este guia descreve os comandos de compilação local do aplicativo, que recebem dependências já preparadas e não as baixam automaticamente.

## Requisitos

- Windows 10 ou 11, x64 Intel/AMD.
- .NET Framework 4.8, incluindo o compilador `csc.exe` disponibilizado pelo Framework.
- Windows PowerShell 5.1 de 64 bits. PowerShell 7 (`pwsh`) não substitui esse requisito.
- [NSIS](https://nsis.sourceforge.io/Download), com Modern UI 2, para gerar o instalador: 3.12 foi validado no build local anterior; 3.10 foi validado na release offline do GitHub. Não é necessário para compilar somente o aplicativo.
- `ffmpeg.exe` e `ffprobe.exe` x64, da mesma compilação, preparados separadamente. O programa utiliza os codificadores `libx264`, `libx265` e `aac`. O fluxo de CI os compila por `ci/Build-FFmpeg.sh`; veja [dependências e distribuição](DEPENDENCIAS.md).
- Git, se for clonar pela linha de comando.

Não é necessário Visual Studio. Os scripts utilizam o compilador do .NET Framework e a biblioteca `System.Management.Automation` do Windows PowerShell.

## 1. Obter o código

Abra o Windows PowerShell em uma pasta de trabalho sua:

```powershell
git clone https://github.com/luziellacerda/APARADOR-LZ.git
Set-Location .\APARADOR-LZ
```

Os comandos abaixo partem da raiz do repositório. Os exemplos usam caminhos ilustrativos para as dependências: substitua-os pela localização real no seu computador.

## 2. Preparar FFmpeg e ffprobe

Para reproduzir a release, use [ci/Build-FFmpeg.sh](../ci/Build-FFmpeg.sh) no ambiente Linux descrito pelo workflow: ele compila fontes fixados e produz `ci-out/bin`, avisos e o arquivo de fontes correspondentes. O script baixa as fontes nesse ambiente de build; o programa instalado não faz esses downloads.

Para experimentar outra dependência local, consulte a [página oficial de downloads do FFmpeg](https://ffmpeg.org/download.html), que oferece o código-fonte e indica fornecedores de builds para Windows. Obtenha um conjunto x64 com os codificadores necessários e confira a origem e os materiais de licença. Prefira executáveis autocontidos: o empacotamento copia somente os dois arquivos `.exe`, não DLLs externas. Uma alternativa local não recebe automaticamente a aprovação nem a procedência da release oficial.

Você pode guardar as dependências fora do repositório, por exemplo em `C:\Ferramentas\ffmpeg\bin`, e passá-las com `-FfmpegDirectory`. Confira primeiro:

```powershell
& 'C:\Ferramentas\ffmpeg\bin\ffmpeg.exe' -version
& 'C:\Ferramentas\ffmpeg\bin\ffprobe.exe' -version
& 'C:\Ferramentas\ffmpeg\bin\ffmpeg.exe' -encoders
```

Alternativamente, coloque `ffmpeg.exe` e `ffprobe.exe` em `vendor\ffmpeg\`. Esse é o diretório padrão, ignorado pelo Git. Não coloque vídeos pessoais nessa pasta. Uma versão diferente das dependências precisa ser validada novamente; a compatibilidade com qualquer build futuro não é garantida.

## 3. Gerar o instalador

Este fluxo compila o aplicativo, inclui os avisos de distribuição, executa o autoteste do EXE e gera o instalador. Não instala o programa ao terminar. Os avisos do FFmpeg e do NSIS precisam corresponder aos componentes efetivamente incluídos.

```powershell
& "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -File .\Build-Installer.ps1 -FfmpegDirectory 'C:\Ferramentas\ffmpeg\bin' -FfmpegNoticePath 'C:\Ferramentas\ffmpeg\docs\TERCEIROS-FFMPEG.txt'
```

Sem `-OutputRoot`, cada execução cria uma pasta nova em `builds\`, com data e identificador. Se as dependências estiverem em `vendor\ffmpeg\`, omita `-FfmpegDirectory`, mas informe o aviso correspondente com `-FfmpegNoticePath`. O aviso não é substituído automaticamente por um texto genérico. `-NsisNoticePath` permite informar o arquivo `COPYING` da instalação NSIS usada; por padrão, usa o aviso local preservado em `docs\TERCEIROS-NSIS.txt`.

Para escolher os caminhos e gerar também a variante isolada de teste:

```powershell
& "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -File .\Build-Installer.ps1 -OutputRoot .\builds\minha-validacao -FfmpegDirectory .\ci-out\bin -FfmpegNoticePath .\ci-out\docs\TERCEIROS-FFMPEG.txt -MakeNsis 'C:\Program Files (x86)\NSIS\makensis.exe' -NsisNoticePath 'C:\Program Files (x86)\NSIS\COPYING' -IncludeTestBuild
```

`-OutputRoot` deve apontar para uma pasta que ainda não existe. Os scripts não apagam builds anteriores. Para repetir o comando, escolha outro nome.

Saídas:

```text
builds/<identificador>/
├── app/
│   ├── APARADOR DE VIDEOS LZ-GAMES.exe
│   ├── bin/ffmpeg.exe
│   ├── bin/ffprobe.exe
│   ├── docs/                  # Documentos TXT e avisos dos componentes
│   └── BUILD-INFO.json        # Metadados locais; não instalado
├── self-test/self-test-result.json
├── LZGames-Aparador-1.3.0-Setup.exe
├── LZGames-Aparador-1.3.0-TESTE-Setup.exe  # Somente com -IncludeTestBuild
└── MANIFEST.json             # Tamanhos e SHA256
```

O aplicativo instalado não precisa de arquivos `.ps1`, `.cs` ou `.bat` soltos: a interface e os controles de segurança são compilados no EXE; o backend PowerShell é um recurso interno. Windows PowerShell 5.1 continua sendo um requisito do sistema. O diretório `bin` continua necessário; não distribua apenas o EXE do aplicativo.

## 4. Compilar apenas o aplicativo

```powershell
& "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -File .\Build-App.ps1 -OutputDirectory .\builds\somente-app -FfmpegDirectory 'C:\Ferramentas\ffmpeg\bin'
```

`-OutputDirectory` aceita pasta nova ou vazia. Sem essa opção, usa `app\`. O comando acima não cria instalador nem executa o autoteste automaticamente. `-IconPath` permite informar outro arquivo `.ico`; o padrão é `assets\LZGames.ico`.

## 5. Validar antes de usar ou distribuir

O autoteste que `Build-Installer.ps1` executa valida o carregamento do backend e controles do aplicativo. Não substitui codificação real de vídeos nem teste de instalação. Consulte [os testes](TESTES.md) para executar a integração com mídia sintética e o ciclo do instalador **TESTE**.

Os relatórios e manifests incluem caminhos absolutos locais. Não os publique sem revisão. Builds não são determinísticos byte a byte: novas compilações podem ter SHA256 diferente mesmo sem mudança no código. Não use o hash de outra máquina como resultado esperado para o seu próprio build.

## Limitações de distribuição

Gerar um instalador não significa que ele está pronto para publicação pública. O fluxo de release usa dependências compiladas dos fontes, inclui seus avisos e anexa os fontes correspondentes. Não publique um pacote alternativo sem reunir os materiais da compilação utilizada. Os binários históricos de 2018 permanecem fora da distribuição pública. Veja [DEPENDENCIAS.md](DEPENDENCIAS.md) e [RELEASE.md](RELEASE.md).

Ao trocar FFmpeg/ffprobe, revise também `docs\LICENSE-info.txt`, os avisos distribuídos e os testes. Aplicativo e instalador não recebem assinatura digital automaticamente. Se o Windows bloquear scripts por política da organização, siga a orientação do administrador; os scripts não alteram essa política.
