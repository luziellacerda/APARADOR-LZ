# Dependências e distribuição

O Git versiona o código do aplicativo e os scripts de compilação, sem incluir executáveis ou vídeos pessoais. O fluxo de release baixa fontes com versões/revisões fixadas, compila as dependências de vídeo e anexa os materiais de distribuição à release. Não usa os EXEs históricos da máquina do desenvolvedor.

O instalador completo contém FFmpeg e ffprobe. A instalação e o aplicativo **não baixam componentes de vídeo**; os downloads de fontes acontecem no ambiente de compilação do GitHub Actions. Consulte [RELEASE.md](RELEASE.md).

## FFmpeg e ffprobe

O programa usa FFmpeg para recodificação e ffprobe para inspeção dos arquivos. O fluxo `ci/Build-FFmpeg.sh` gera dois executáveis Windows x64 da mesma compilação, com os codificadores `libx264`, `libx265` e `aac`, incluindo estaticamente as bibliotecas de vídeo necessárias. O empacotador não suporta distribuições que precisem de DLLs externas não incluídas no pacote.

As fontes estão fixadas em [dependencies.lock.json](../ci/dependencies.lock.json): FFmpeg **8.1.3**, x264 no commit `0480cb05fa188d37ae87e8f4fd8f1aea3711f7ee` e x265 **4.1**, com os URLs e SHA256 dos arquivos. Flags e preparação do ambiente estão no [script de compilação](../ci/Build-FFmpeg.sh). A release acompanha:

- `FFmpeg-corresponding-source.tar.xz`, com os fontes correspondentes e os materiais de reconstrução das dependências.
- `docs/TERCEIROS-FFMPEG.txt`, instalado junto com o programa, identificando os componentes e suas condições.
- Manifesto e SHA256 vinculando o instalador aos arquivos efetivamente compilados e testados.

Preserve esses materiais quando redistribuir os componentes. Alterar fontes, flags ou bibliotecas pode alterar os requisitos de distribuição e precisa de nova revisão. Os termos de FFmpeg, x264 e x265 não são substituídos pela documentação do LZ Games. As [orientações oficiais do FFmpeg](https://ffmpeg.org/legal.html) descrevem os efeitos das opções e bibliotecas habilitadas no licenciamento.

A [página oficial de downloads](https://ffmpeg.org/download.html) disponibiliza fontes e indica fornecedores de builds para Windows. O FFmpeg não fornece diretamente os EXEs Windows nessa página. A procedência e os materiais que acompanham a compilação escolhida devem ser conferidos.

Para uma compilação local, use `vendor\ffmpeg\` ou informe `-FfmpegDirectory`, preferindo o resultado de `ci/Build-FFmpeg.sh` e seu aviso correspondente. Veja [COMPILAR.md](COMPILAR.md). Os diretórios dos executáveis e builds são ignorados pelo Git.

## Situação dos binários históricos

Os testes locais originais do LZ Games 1.3.0 reaproveitaram FFmpeg/ffprobe `N-92522-g370b8bd847`, de 2018. Esses executáveis informam `--enable-gpl --enable-version3`, incluem libx264/libx265 e declaram GPL versão 3 ou posterior em `ffmpeg.exe -L`.

O pacote recebido não continha o conjunto completo de fontes correspondentes, materiais de licença e procedência verificável. Esse material não foi reconstruído. Os binários antigos ficaram restritos à validação local e **não são usados nem distribuídos no fluxo público**. Eles são substituídos por componentes compilados dos fontes no Actions. Não foi realizada auditoria de vulnerabilidades dos binários históricos.

A publicação dos fontes do aplicativo não substitui os materiais de seus componentes. Os testes históricos com executáveis de 2018 não aprovam a nova compilação: o fluxo exige uma nova validação antes da publicação. Este documento não declara uma auditoria jurídica, comercial ou de vulnerabilidades concluída.

## .NET Framework e Windows PowerShell

O aplicativo utiliza .NET Framework 4.8, Windows Forms e `System.Management.Automation` do Windows PowerShell 5.1. São requisitos do Windows e não são copiados para o instalador. O backend está embutido no EXE, mas continua usando o runtime PowerShell do sistema.

Plataforma prevista: Windows 10/11 x64 Intel/AMD. O instalador verifica localmente os pré-requisitos, sem download automático. Windows ARM64 e Windows de 32 bits não fazem parte dessa configuração validada.

## NSIS

O instalador utiliza NSIS, Modern UI 2 e compressão LZMA. O fluxo de CI seleciona NSIS 3.10 do runner Windows e o submete novamente ao ciclo completo de testes. O build local anterior foi validado com NSIS 3.12. Os avisos da versão efetivamente usada no Actions são copiados de seu arquivo `COPYING` para `docs/TERCEIROS-NSIS.txt` no instalador.

A instalação do NSIS é necessária apenas para compilar o instalador; não é requisito para executar o programa instalado. Consulte o [projeto NSIS](https://nsis.sourceforge.io/Download). A versão local dos avisos está em [TERCEIROS-NSIS.txt](TERCEIROS-NSIS.txt).

## Código do aplicativo e assinatura

Não foi atribuída uma licença nova ao código do aplicativo. A publicação neste repositório, por si só, não representa uma autorização adicional para reutilização. A escolha de uma licença deve ser feita pelo titular do projeto, sem substituir os termos dos componentes de terceiros.

Aplicativo e instalador não são assinados com Authenticode nesta entrega. O Windows pode identificar o editor como desconhecido. A compilação não compra certificado, não altera as proteções do Windows e não transforma código embutido em proteção contra engenharia reversa.
