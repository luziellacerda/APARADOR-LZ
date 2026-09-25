# Testes e limites da validação

Os testes do aplicativo precisam do Windows e podem ser executados localmente ou no GitHub Actions. Leia os scripts antes de executá-los: o teste de mídia cria arquivos de vídeo sintéticos; o teste do instalador instala e remove uma variante identificada como **TESTE** no perfil atual do Windows.

Não use seus vídeos pessoais como material de teste. Os exemplos abaixo partem da raiz deste repositório e usam uma pasta de build nova dentro dele.

## Interface Video Studio 1.4.0

O teste `tests/Test-PremiumUI.ps1` carrega os controles do EXE compilado, renderiza as três abas em 1260×720 e 960×560 e verifica os controles principais dentro da janela. Exercita também os campos de início/fim, separadores decimais, intervalo inválido e 12 ciclos de abertura/seleção/fechamento do menu. Foram aprovadas 76 verificações locais em 25/09/2026, e as imagens renderizadas foram inspecionadas. Um texto encoberto no estado vazio da janela mínima foi corrigido e renderizado novamente.

Na mesma compilação, o autoteste passou em 14 verificações e `Test-PackagedMedia.ps1 -AllProfiles` passou em 142 verificações. Foram usados os componentes FFmpeg/ffprobe da release pública 1.3.0, com hashes conferidos, sem alterar os vídeos do usuário. A versão do aplicativo é 1.4.0; os codecs não mudaram.

O instalador TESTE dessa mesma compilação passou em 133 verificações locais de instalação, reinstalação, desinstalação e preservação de arquivos sentinela. O instalador de produção não foi instalado automaticamente. Essa validação local não significa que uma release 1.4.0 já tenha sido publicada no GitHub.

```powershell
powershell.exe -NoProfile -File .\tests\Test-PremiumUI.ps1 -AppRoot .\builds\validacao-local-001\app -OutputDirectory .\builds\validacao-local-001\ui
```

Essa renderização usa os próprios controles WinForms e não equivale a uma sessão manual no desktop nem certifica todos os níveis de DPI. Em janelas pequenas as configurações têm rolagem, mantendo os botões principais acessíveis. Os testes não cobrem todas as combinações de formatos, resoluções e FPS.

## Resultado histórico da versão 1.3.0

A entrega local de 25/09/2026 foi validada com estes resultados:

| Verificação | Resultado | O que foi exercitado |
| --- | --- | --- |
| Autoteste do aplicativo compilado | 14 verificações passaram | Controles compilados, recorte 7 → 22, separadores decimais, rejeição de intervalo inválido, leitura recursiva e argumentos de áudio. |
| Processamento real de mídia | 85 verificações passaram | Nove codificações e três resultados ignorados/preservados, com duração, áudio, organização das subpastas e decodificação completa conferidos. |
| Ciclo do instalador TESTE | 122 verificações passaram | Instalação, autoteste do EXE instalado, bloqueio de arquivo em uso, reinstalação, desinstalação e preservação de arquivos sentinela. |

O autoteste de 14 verificações também foi executado dentro do ciclo do instalador; não representa uma quarta bateria independente. O teste de mídia usou três vídeos sintéticos de quatro segundos, incluindo caminhos com acentos e arquivos de mesmo nome em subpastas diferentes:

1. Recorte de 0,5 a 2,25 segundos, sem áudio: três resultados de 1,75 segundo.
2. Nova tentativa sem permitir substituição: os três resultados anteriores foram preservados por comparação de SHA256.
3. Substituição autorizada com recorte de 1 a 2 segundos: três resultados de um segundo.
4. Vídeo inteiro com áudio: três resultados de quatro segundos.

Os originais sintéticos também tiveram os hashes conferidos. O backend foi carregado do recurso interno do EXE compilado, não de um arquivo PowerShell externo. O teste de mídia utiliza o perfil H.264; não é uma bateria completa de todos os perfis H.265, resoluções, FPS e formatos de entrada.

Esses números descrevem a entrega local anterior à organização deste repositório. Os relatórios locais completos contêm caminhos da máquina e não são publicados no Git.

## Revalidação durante a preparação do repositório

Em 25/09/2026, após organizar o projeto e tornar configurável o diretório do FFmpeg, uma nova compilação local foi validada:

- **85 verificações de mídia passaram**, com nove codificações e três resultados preservados.
- **122 verificações do instalador TESTE passaram**, incluindo instalação, reinstalação e desinstalação. Os seis arquivos instalados corresponderam ao payload, seis sentinelas foram preservadas e o registro de produção permaneceu inalterado. Registro e atalhos TESTE foram removidos ao concluir.
- O **autoteste do EXE instalado passou nas 14 verificações**. Seu hash coincidiu com o EXE usado no teste de mídia, ligando as duas baterias ao mesmo aplicativo compilado.
- Um **checkout limpo de um commit local da preparação** também compilou pelo Windows PowerShell 5.1; seu EXE passou nas 14 verificações do autoteste. O teste deixou o checkout sem alterações versionáveis.

As dependências de vídeo continuaram sendo os binários históricos usados apenas localmente, descritos em [DEPENDENCIAS.md](DEPENDENCIAS.md). Os instaladores de produção gerados nesta preparação não foram instalados automaticamente nem publicados no repositório.

**Esses são testes locais, não resultados de CI nem certificação de uma compilação futura.** As contagens repetem a mesma bateria e não representam cobertura adicional de todos os formatos ou computadores. Alterar o build, as dependências ou o ambiente exige executar novamente os testes. Os resultados brutos permaneceram fora do Git para não expor caminhos pessoais.

## Validação no GitHub Actions

**Release `v1.3.0` aprovada em 25/09/2026:** [execução 36146748027](https://github.com/luziellacerda/APARADOR-LZ/actions/runs/36146748027), commit `7e35cedf1db72c99ab0c916555d6f83475fc0a0f`. Resultado: **142 verificações de mídia, 133 do instalador e 14 do autoteste passaram**. FFmpeg 8.1.3, x264 e x265 4.1 foram compilados dos fontes; os binários históricos não foram usados. O [manifesto publicado](https://github.com/luziellacerda/APARADOR-LZ/releases/download/v1.3.0/RELEASE-MANIFEST.json) registra os hashes e resultados dessa entrega.

O [workflow de release](../.github/workflows/release.yml) compila novas dependências dos fontes e executa as baterias no runner Windows. A etapa de mídia usa `-AllProfiles`: além dos casos H.264 históricos abaixo, exercita os três perfis H.265 com recorte, áudio, pastas e decodificação dos resultados. A contagem de verificações cresce; o valor real fica no `RELEASE-MANIFEST.json` daquela execução.

A release exige todos esses casos, autoteste aprovado e ciclo completo de instalação/reinstalação/desinstalação. A versão **TESTE** inclui o mesmo payload de execução que o instalador de produção. Acrescentar um aviso de terceiro ao payload também aumenta as verificações de arquivos do instalador. Não use 85/122 como limite máximo nem como resultado presumido de um novo build.

Consulte [Actions](https://github.com/luziellacerda/APARADOR-LZ/actions) para o resultado de cada execução e [RELEASE.md](RELEASE.md) para os arquivos públicos. A aprovação desta release não certifica compilações futuras. Relatórios brutos e vídeos sintéticos não são anexados à release pública.

## Preparar uma compilação para testar

Use Windows 10/11 x64, .NET Framework 4.8 e **Windows PowerShell 5.1 de 64 bits**. PowerShell 7 não substitui esse runtime. Para gerar o instalador, também é necessário o NSIS. Consulte [COMPILAR.md](COMPILAR.md) para preparar os executáveis FFmpeg/ffprobe, que não são distribuídos neste repositório.

Escolha um nome de pasta ainda não existente:

```powershell
$build = Join-Path $PWD 'builds\validacao-local-001'

powershell.exe -NoProfile -File .\Build-Installer.ps1 `
  -FfmpegDirectory .\ci-out\bin `
  -FfmpegNoticePath .\ci-out\docs\TERCEIROS-FFMPEG.txt `
  -OutputRoot $build `
  -IncludeTestBuild
```

Se o NSIS estiver em outro local, informe `-MakeNsis` com o caminho de `makensis.exe`. O build gera os instaladores, mas **não os instala automaticamente**. Também executa o autoteste do aplicativo. Use outra pasta de saída nas próximas compilações para conservar as evidências anteriores.

## Autoteste do EXE

Este teste verifica a integração do backend embutido e dos controles. Ele não codifica vídeos nem mostra a janela principal. A pasta de dados precisa ser nova: o aplicativo rejeita uma pasta já existente quando `--self-test` está ativo.

```powershell
$exe = Join-Path $build 'app\APARADOR DE VIDEOS LZ-GAMES.exe'
$data = Join-Path $build ('autoteste-manual-' + [guid]::NewGuid().ToString('N'))
$processo = Start-Process -FilePath $exe `
  -ArgumentList @('--self-test', '--data-root', ('"{0}"' -f $data)) `
  -WindowStyle Hidden -Wait -PassThru

if ($processo.ExitCode -ne 0) { throw 'O autoteste do EXE falhou.' }
Get-Content -LiteralPath (Join-Path $data 'self-test-result.json') -Raw
```

Confira `Passed: true` e as verificações descritas no JSON; não considere apenas a existência do arquivo.

## Codificação e pastas de verdade

Execute o script em um processo separado do Windows PowerShell para que o teste carregue exatamente a compilação escolhida:

```powershell
powershell.exe -NoProfile -STA -File .\Test-PackagedMedia.ps1 `
  -AppRoot (Join-Path $build 'app') -AllProfiles

if ($LASTEXITCODE -ne 0) { throw 'O teste de processamento falhou.' }
```

O script cria uma pasta exclusiva em `media-tests\<identificador>`, gera os vídeos sintéticos e usa os mesmos caminhos de processamento do aplicativo. Ao terminar, informa onde salvou `result.json`. O resultado precisa ser `Passed: true`, com `PACKAGED_MEDIA_PASS` e a contagem efetiva. Sem `-AllProfiles`, roda somente a bateria histórica de 85 verificações; essa execução reduzida não basta para preparar uma release pública.

O material de teste e o relatório ficam no disco como evidência. Não são enviados automaticamente e não devem entrar no commit. As verificações cobrem preservação dos originais, preservação e substituição explícita dos resultados, duração, opção de áudio, estrutura recursiva e ausência de arquivos temporários inacabados.

## Instalação, reinstalação e remoção

**Execute apenas uma instância deste teste por vez.** A variante TESTE usa um identificador fixo, registro em `HKCU` e atalhos próprios no Menu Iniciar. Não execute o teste durante outra instalação ou desinstalação da variante TESTE.

Tanto o instalador quanto a pasta `app` precisam estar dentro do repositório: o script rejeita caminhos externos e caminhos com junctions ou links simbólicos. Não passe o instalador de produção. Feche programas de teste que estejam usando os arquivos da compilação.

```powershell
$setupTeste = Join-Path $build 'LZGames-Aparador-1.3.0-TESTE-Setup.exe'
$sha256 = (Get-FileHash -LiteralPath $setupTeste -Algorithm SHA256).Hash

powershell.exe -NoProfile -File .\tests\Test-Installer.ps1 `
  -InstallerPath $setupTeste `
  -ExpectedInstallerSha256 $sha256 `
  -PayloadRoot (Join-Path $build 'app')

if ($LASTEXITCODE -ne 0) { throw 'O ciclo do instalador falhou. Leia o relatório.' }
```

O hash vincula a execução ao artefato escolhido; calcular um hash não comprova a origem ou segurança de um arquivo desconhecido. Use o instalador TESTE que você acabou de compilar e revisar.

O script:

- Confere nome, metadados e SHA256 antes de executar o instalador.
- Recusa iniciar se já existir registro ou atalho da variante TESTE.
- Instala em uma pasta nova de `tests\runs\<identificador>`.
- Confere os hashes dos arquivos instalados e executa o autoteste daquele EXE.
- Testa bloqueios de destino ocupado, executável em uso e pasta contendo marcadores de vídeos.
- Reinstala e desinstala pelo instalador/desinstalador da variante TESTE.
- Confere arquivos sentinela, dados externos à pasta do aplicativo e preservação do registro de produção.

O relatório fica em `tests\runs\<identificador>\installer-test-result.json`. Na configuração completa atual, o resultado histórico foi `Passed: true; assertions: 122`. Não use `-SkipReinstall` quando quiser reproduzir o ciclo completo.

Sentinelas e relatórios permanecem no disco. O próprio `Desinstalar.exe` pode permanecer porque o teste o executa diretamente com o parâmetro NSIS `_?=`; isso é registrado como resíduo esperado. O script não faz limpeza recursiva. Se ocorrer falha após a instalação, leia o relatório e verifique a instalação **TESTE** registrada antes de tentar novamente. Não remova indiscriminadamente pastas, registros ou atalhos de produção para contornar a falha.

## O que ainda exige avaliação

Esses testes não simulam uma instalação limpa de todas as versões do Windows, não auditam vulnerabilidades do FFmpeg e não verificam assinatura digital. Também não substituem testes manuais da interface, acessibilidade, diferentes tamanhos de tela, arquivos grandes, mídia danificada, discos de rede e cancelamento em todas as etapas.

Uma nova dependência de vídeo deve ser testada com os perfis e formatos que serão utilizados. Não há promessa de compactação sem perda visual, tamanho final menor em todos os casos ou compatibilidade com todos os vídeos.

Antes de publicar logs ou relatar um problema, remova nomes pessoais, caminhos de arquivos e outros dados privados. Informe a versão do aplicativo, a versão de FFmpeg usada, as opções escolhidas e um exemplo sintético que reproduza a falha.
