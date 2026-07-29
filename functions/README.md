# Invitaciones seguras de pareja

Este backend expone dos funciones callable autenticadas:

- `createPairInvitation`: crea o recupera una invitación activa de 15 minutos.
- `acceptPairInvitation`: valida el código y vincula ambos usuarios de forma
  atómica.

Las funciones están configuradas en `us-central1` y requieren Node.js 22.

## Despliegue

Desde la raíz del proyecto:

```powershell
firebase login
firebase use datty-app
firebase deploy --only functions
```

El proyecto de Firebase debe usar el plan Blaze para desplegar Cloud Functions.

## Reglas

Las aplicaciones cliente no deben escribir ni leer directamente las
colecciones `pairInvites` y `pairInviteOwners`. Integra el contenido de
`firestore.pairing.rules.snippet` dentro de las reglas existentes y despliega
las reglas después de comprobar que no reemplazas los permisos de las demás
colecciones.

## Limpieza automática

Cada invitación contiene `cleanupAt`, 24 horas posterior a su expiración.
En Firestore, crea una política TTL para:

- Colección: `pairInvites`
- Campo: `cleanupAt`

Firestore eliminará posteriormente las invitaciones usadas, canceladas o
vencidas. La validez nunca depende del TTL: la función siempre comprueba
`status` y `expiresAt`.

## App Check

Después de registrar Android e iOS en Firebase App Check y comprobar que los
tokens llegan correctamente, se puede activar `enforceAppCheck: true` en las
opciones de ambas funciones callable. No lo actives antes de configurar los
proveedores, porque bloquearía también la aplicación legítima.
