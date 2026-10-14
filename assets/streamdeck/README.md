# Stream Deck

Un perfil por juego para el Stream Deck del dealer (MK.2 de 15 teclas). Se generan con `~/Kerma/streamdeck/build_dealer_profiles.py`. Diseño cerrado con los supervisores el 14-oct-2026.

| Archivo | Nombre en la app | Mesas |
|---|---|---|
| `craps.streamDeckProfile` | Craps | Craps |
| `roulette.streamDeckProfile` | Roulette | Ruleta |
| `blackjack.streamDeckProfile` | Blackjack | Blackjack 01 a 04 |
| `blackjack-unlimited.streamDeckProfile` | Blackjack | Blackjack Unlimited (copia del de Blackjack) |

Las teclas pegan el comando en la Dealer App sin Enter, salvo ENTRAR (`{SIGN_IN}`, en el teclado del PIN), que pulsa Enter después. En la última columna van siempre EMERGENCY, PIT MANAGER y SIGN, que abre el teclado del PIN.

El script abre el perfil con la app de Stream Deck, que lo importa. Guarda la huella del perfil importado en `C:\ProgramData\Kerma\streamdeck-<juego>.sha256`:

- Si el perfil del repositorio no ha cambiado, no hace nada (volver a importarlo crearía "Craps 2").
- Si ha cambiado, cierra la app de Stream Deck, guarda el perfil que tenía la app con ese nombre en `C:\KermaSetup\backup\streamdeck-<fecha>\`, lo borra e importa el nuevo.

Si después el Stream Deck muestra otro perfil, elígelo en la app.

El control de la mesa (pausar, reanudar, cámaras...) no va aquí: va en los Stream Deck de los supervisores, con Companion y Kerma Remote.
