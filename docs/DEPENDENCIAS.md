# Dependências e distribuição

O repositório publica o código do aplicativo e os scripts de compilação, sem incluir `ffmpeg.exe`, `ffprobe.exe`, vídeos pessoais ou instaladores. Nenhum script baixa essas dependências automaticamente.

## FFmpeg e ffprobe

O programa usa FFmpeg para recodificação e ffprobe para inspeção dos arquivos. Forneça separadamente dois executáveis Windows x64 da mesma compilação, com os codificadores `libx264`, `libx265` e `aac`. O empacotador copia somente esses dois EXEs; builds que exigem DLLs externas precisam de adaptação e não são suportados por esse empacotamento.

A [página oficial de downloads](https://ffmpeg.org/download.html) disponibiliza fontes e indica fornecedores de builds para Windows. O FFmpeg não fornece diretamente os EXEs Windows nessa página. A procedência e os materiais que acompanham a compilação escolhida devem ser conferidos.

Use `vendor\ffmpeg\` ou informe `-FfmpegDirectory` ao compilar. Veja [COMPILAR.md](COMPILAR.md). O diretório dos executáveis é ignorado pelo Git.

## Situação dos binários históricos

Os testes locais originais do LZ Games 1.3.0 reaproveitaram FFmpeg/ffprobe `N-92522-g370b8bd847`, de 2018. Esses executáveis informam `--enable-gpl --enable-version3`, incluem libx264/libx265 e declaram GPL versão 3 ou posterior em `ffmpeg.exe -L`.

O pacote recebido não continha o conjunto completo de fontes correspondentes, materiais de licença e procedência verificável. Esse material não foi reconstruído. Os binários antigos ficaram restritos à validação local; **não há instalador público com eles neste repositório**. Não foi realizada auditoria de vulnerabilidades dessas dependências.

A publicação dos fontes do aplicativo não resolve automaticamente os requisitos de redistribuição de seus componentes. Antes de disponibilizar um instalador público ou comercial, escolha dependências com origem e materiais documentados, revise os avisos de distribuição e valide novamente o aplicativo. Consulte as [orientações oficiais de licenciamento do FFmpeg](https://ffmpeg.org/legal.html). Este documento registra a situação da entrega; não declara conformidade de redistribuição já concluída.

## .NET Framework e Windows PowerShell

O aplicativo utiliza .NET Framework 4.8, Windows Forms e `System.Management.Automation` do Windows PowerShell 5.1. São requisitos do Windows e não são copiados para o instalador. O backend está embutido no EXE, mas continua usando o runtime PowerShell do sistema.

Plataforma prevista: Windows 10/11 x64 Intel/AMD. O instalador verifica localmente os pré-requisitos, sem download automático. Windows ARM64 e Windows de 32 bits não fazem parte dessa configuração validada.

## NSIS

O instalador utiliza NSIS 3.12, Modern UI 2 e compressão LZMA. A instalação do NSIS é necessária apenas para compilar o instalador; não é requisito para executar o programa instalado. Consulte o [projeto NSIS](https://nsis.sourceforge.io/Download) e os avisos preservados em [TERCEIROS-NSIS.txt](TERCEIROS-NSIS.txt).

## Código do aplicativo e assinatura

Não foi atribuída uma licença nova ao código do aplicativo. A publicação neste repositório, por si só, não representa uma autorização adicional para reutilização. A escolha de uma licença deve ser feita pelo titular do projeto, sem substituir os termos dos componentes de terceiros.

Aplicativo e instalador não são assinados com Authenticode nesta entrega. O Windows pode identificar o editor como desconhecido. A compilação não compra certificado, não altera as proteções do Windows e não transforma código embutido em proteção contra engenharia reversa.
