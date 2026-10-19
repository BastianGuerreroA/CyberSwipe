extends Node
## Administrador criptográfico para descifrar cápsulas educativas (.lsg).
## Implementa descifrado AES-256-CBC con relleno PKCS#7 a partir de datos binarios
## generados por la herramienta de cifrado offline.
##
## Formato del archivo binario .lsg:
## [16 bytes IV][Texto cifrado...]

var AES_KEY: PackedByteArray = PackedByteArray([
	216,159,99,164,211,178,86,149,
	70,65,192,153,222,234,174,136,
	232,107,140,46,156,203,66,216,
	65,240,188,83,95,84,161,42
])

## Carga y descifra el archivo de una cápsula educativa retornando su estructura JSON como Dictionary.
func load_capsule(path: String) -> Dictionary:
	return _load_json(path)

## Carga y descifra el archivo de índice general de contenido (index.lsg).
func load_index(path: String) -> Dictionary:
	return _load_json(path)

## Lee los bytes crudos del archivo en disco y delega su descifrado.
func _load_json(path: String) -> Dictionary:
	if !FileAccess.file_exists(path):
		push_error("CryptoManager -> No existe: " + path)
		return {}

	var encrypted := FileAccess.get_file_as_bytes(path)
	if encrypted.is_empty():
		push_error("CryptoManager -> Archivo vacío.")
		return {}

	return _decrypt(encrypted)

## Descifra el buffer binario AES-256-CBC extrayendo el IV inicial y parseando el texto plano resultante.
func _decrypt(file_bytes: PackedByteArray) -> Dictionary:
	if file_bytes.size() <= 16:
		push_error("CryptoManager -> Archivo inválido.")
		return {}

	var iv: PackedByteArray = file_bytes.slice(0, 16)
	var ciphertext: PackedByteArray = file_bytes.slice(16)

	var aes := AESContext.new()
	var err := aes.start(AESContext.MODE_CBC_DECRYPT, AES_KEY, iv)
	if err != OK:
		push_error("CryptoManager -> Error AES start().")
		return {}

	var decrypted := aes.update(ciphertext)
	aes.finish()

	decrypted = _remove_padding(decrypted)
	var json_text := decrypted.get_string_from_utf8()

	var json := JSON.new()
	err = json.parse(json_text)
	if err != OK:
		push_error(
			"CryptoManager -> JSON inválido.\n" +
			json.get_error_message() +
			"\nLínea: " +
			str(json.get_error_line())
		)
		return {}

	return json.data

## Remueve el relleno PKCS#7 del buffer de bytes descifrado según el último byte.
func _remove_padding(data: PackedByteArray) -> PackedByteArray:
	if data.is_empty():
		return data

	var padding := data[data.size() - 1]
	if padding <= 0 or padding > 16:
		return data

	return data.slice(0, data.size() - padding)
