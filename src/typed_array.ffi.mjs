export function NewUint8Array() {
    return new Uint8Array();
}

export function fromList(list) {
    const array = list.toArray();
    return new Uint8Array(array);
}
