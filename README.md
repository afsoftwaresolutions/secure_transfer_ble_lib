# Secure BLE Transfer

Paquete Flutter para transferir cadenas de texto entre dispositivos cercanos mediante QR y Bluetooth Low Energy (BLE). Cada mensaje se cifra con una clave de sesión derivada por ECDH y se confirma mediante un ACK antes de enviar el siguiente.

La interfaz para mostrar y escanear el QR pertenece a la app que integra el paquete. Consulta `example/` para ver una implementación.

## Instalación desde GitHub

```yaml
dependencies:
  secure_transfer_poc_flutter:
    git:
      url: https://github.com/afsoftwaresolutions/secure_transfer_ble_lib.git
      ref: master
```

Usa la misma versión del paquete en ambos dispositivos. Para una integración estable, fija `ref` a un tag o commit en vez de `master`.

## Crear la instancia

```dart
import 'package:secure_transfer_poc_flutter/secure_transfer_poc_flutter.dart';

final transfer = SecureBleTransfer.create(appId: 'INTERAPP');
```

Los dos extremos de una transferencia deben usar el mismo `appId`. Por ejemplo, Interapp puede usar `INTERAPP` y App Controller `APP_CONTROLLER`. La instancia predeterminada conserva el identificador del POC para las pruebas con la versión Kotlin original.

## Enviar

```dart
final invitation = await transfer.startSending();

// Muestra invitation.invitationJson como código QR.
```

Cuando `senderState.status` sea `BlePeripheralStatus.sessionKeyReady`, envía cada cadena por separado:

```dart
for (final json in jsonStrings) {
  await transfer.sendText(json); // Espera el ACK de este mensaje.
}
```

La conexión permanece abierta para enviar más cadenas. Al terminar:

```dart
await transfer.stopSending();
```

## Recibir

Inicia la escucha de mensajes antes de conectar:

```dart
final messagesSubscription = transfer.receivedTexts.listen((text) {
  // Procesa cada cadena recibida.
});
```

Después de escanear el QR con la cámara de la app:

```dart
await transfer.prepareReceiving(scannedQrText);
await transfer.connectReceiver();
```

`connectReceiver()` inicia la búsqueda BLE. Observa `receiverStates` para conocer el progreso y los errores; su `Future` no significa que el handshake ya haya terminado.

Al terminar:

```dart
await transfer.stopReceiving();
await messagesSubscription.cancel();
```

## Consultar estados

`senderState` y `receiverState` devuelven una fotografía del estado actual. `senderStates` y `receiverStates` emiten los cambios:

```dart
final senderSubscription = transfer.senderStates.listen((state) {
  if (state.status == BlePeripheralStatus.sessionKeyReady ||
      state.status == BlePeripheralStatus.dataConfirmed) {
    // Listo para enviar otro texto.
  }
});

final receiverSubscription = transfer.receiverStates.listen((state) {
  // Actualiza la interfaz con state.status y state.message.
});
```

Cancela estas suscripciones cuando la pantalla deje de observarlas. Cancelarlas no cierra BLE: usa `stopSending()` o `stopReceiving()`.

## Permisos de la app anfitriona

La app que integra el paquete debe declarar los permisos BLE en su `AndroidManifest.xml` y la descripción de uso de Bluetooth en `ios/Runner/Info.plist`. Si muestra y escanea QR, también necesita el permiso de cámara. `example/android/app/src/main/AndroidManifest.xml` y `example/ios/Runner/Info.plist` contienen la configuración utilizada por la demo.

## Compatibilidad y alcance

La demo se ha probado en Android con envíos consecutivos sin volver a escanear el QR, incluso entre la versión Flutter y el POC Android Kotlin usando el identificador predeterminado. El flujo iOS requiere pruebas en un dispositivo Apple.

`appId` comprueba que ambos extremos declaren el mismo tipo de app dentro del protocolo; por sí solo no certifica la identidad de una instalación. Si la versión Kotlin va a usar `INTERAPP` o `APP_CONTROLLER`, debe configurarse con el mismo identificador.
