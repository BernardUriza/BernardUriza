# /anydesk - Conectar a PC remota via AnyDesk

## Instrucciones

Comando de utilidad para conectar rapidamente a la PC remota via AnyDesk.

### Al ejecutar:

1. Recuperar el password del macOS Keychain:
   ```bash
   security find-generic-password -s "AnyDesk-RemotePC" -w
   ```

2. Abrir AnyDesk con la conexion al ID remoto:
   ```bash
   open "anydesk:387515268"
   ```

3. Informar al usuario:
   - Que AnyDesk se abrio con la conexion al ID **387515268**
   - Mostrar el password recuperado del Keychain para que lo pegue en el prompt de AnyDesk
   - Si el password no se encuentra en Keychain, avisar que lo configure manualmente

## Reglas

- NUNCA guardar el password en texto plano ni en logs
- NUNCA mostrar el password fuera del contexto de este comando
- Si el Keychain no tiene la entrada "AnyDesk-RemotePC", instruir al usuario a guardarla con:
  `security add-generic-password -a "bernarduriza" -s "AnyDesk-RemotePC" -l "AnyDesk Remote PC (387515268)" -w "TU_PASSWORD" ~/Library/Keychains/login.keychain-db`
