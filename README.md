# CaronaUni

Aplicativo de caronas para a comunidade acadêmica, desenvolvido em Flutter como trabalho da faculdade.

## Conteúdo

- `CaronaUni_DRS.docx`: Documento de Requisitos de Software.
- `caronauni_app/`: aplicativo Flutter (Android, iOS e web).

## Como rodar

Requer o [Flutter](https://docs.flutter.dev/get-started/install) 3.47 ou superior.

```bash
cd caronauni_app
flutter pub get
flutter run            # no emulador ou celular conectado
flutter run -d chrome  # no navegador
```

O app usa Firebase (login e banco de dados). Para rodar sem Firebase, com dados de exemplo:

```bash
flutter run -d chrome --dart-define=DEMO=true
```

Contas da demonstração, com senha `carona123`: `demo@sempreuninassau.com.br` (passageiro), `marina@sempreuninassau.com.br` (motorista) e `admin@sempreuninassau.com.br` (administração).

O cadastro usa e-mail pessoal, confirmado por link, e a matrícula. Só depois de a administração aprovar a matrícula (Perfil > Administração) a pessoa usa as caronas.

As regras de segurança do banco estão em `firestore.rules`. Para tornar alguém administrador, crie no console do Firebase o documento `admins/<uid da pessoa>`.

## Testes

```bash
cd caronauni_app
flutter analyze
flutter test
```

## Equipe

- Esdras Elohim Cardoso Silva
- Eduardo Martins da Silva
- Thiago Victor Dias Macêdo
