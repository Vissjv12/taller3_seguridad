-- =====================================================================
--  Taller 3 - Regla propia: consistencia entre usuario autenticado,
--  sobre (MAIL FROM) y encabezado From: visible.
--
--  Problema que cierra: Postfix (reject_sender_login_mismatch) solo
--  controla el SOBRE. Ana, autenticada, podía enviar con
--  "MAIL FROM:<ana@lab.test>" pero "From: pedro@lab.test", y como Rspamd no
--  aplica DMARC a usuarios autenticados, Pedro recibía un correo que parecía
--  suyo. Esta regla lo rechaza.
-- =====================================================================

local function direccion(lista)
  if lista and lista[1] and lista[1].addr then
    return string.lower(lista[1].addr)
  end
  return nil
end

rspamd_config:register_symbol({
  name = 'LAB_FROM_NO_COINCIDE',
  type = 'normal',
  score = 10.0,
  group = 'taller3',
  description = 'Usuario autenticado con From: visible distinto a su cuenta',
  callback = function(task)
    local usuario = task:get_user()
    if not usuario then return false end      -- solo correo autenticado (587)
    usuario = string.lower(usuario)

    local cabeceras_from = task:get_from('mime') or {}
    local hdr = direccion(cabeceras_from)
    local sobre = direccion(task:get_from('smtp'))

    local motivo
    if #cabeceras_from ~= 1 then
      motivo = 'el mensaje debe tener exactamente un From:'
    elseif hdr ~= usuario then
      motivo = string.format('From: %s no coincide con el usuario %s', hdr or '?', usuario)
    elseif sobre and sobre ~= hdr then
      motivo = string.format('sobre %s distinto del From: %s', sobre, hdr)
    end

    if motivo then
      task:set_pre_result('reject', 'Suplantacion interna: ' .. motivo, 'taller3')
      return true, motivo
    end
    return false
  end,
})
