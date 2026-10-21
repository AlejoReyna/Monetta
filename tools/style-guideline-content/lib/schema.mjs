// Small validator for the JSON Schema vocabulary used by this contract.
// No coercion, defaults, network resolution, or execution of input data.
const isObject = value => value !== null && typeof value === 'object' && !Array.isArray(value);
const matchesType = (value, type) => ({
  object: isObject(value), array: Array.isArray(value), string: typeof value === 'string',
  integer: Number.isInteger(value), number: typeof value === 'number' && Number.isFinite(value),
  boolean: typeof value === 'boolean', null: value === null,
})[type] === true;
const pointer = key => String(key).replaceAll('~', '~0').replaceAll('/', '~1');

export function validateSchema(value, schema, root = schema, at = '') {
  const errors = [];
  const add = (code, message, suffix = '') => errors.push({ code, path: at + suffix, message });
  if (schema.$ref) {
    if (!schema.$ref.startsWith('#/')) throw new Error(`Only local $ref is supported: ${schema.$ref}`);
    const target = schema.$ref.slice(2).split('/').reduce((node, key) => node?.[key.replaceAll('~1', '/').replaceAll('~0', '~')], root);
    if (!target) throw new Error(`Unknown $ref: ${schema.$ref}`);
    return validateSchema(value, target, root, at);
  }
  if (schema.type && ![].concat(schema.type).some(type => matchesType(value, type))) {
    add('INVALID_FIELD_TYPE', `Expected ${[].concat(schema.type).join(' or ')}.`);
    return errors;
  }
  // Evaluate every branch with the same root so nested local $ref keeps working.
  // Do not leak rejected-branch errors when another branch satisfies anyOf.
  if (schema.anyOf && !schema.anyOf.some(branch => validateSchema(value, branch, root, at).length === 0)) add('SCHEMA_ANY_OF_MISMATCH', 'Value must match at least one allowed schema.');
  if (schema.oneOf) {
    const matches = schema.oneOf.filter(branch => validateSchema(value, branch, root, at).length === 0).length;
    if (matches !== 1) add('SCHEMA_ONE_OF_MISMATCH', `Value must match exactly one allowed schema; matched ${matches}.`);
  }
  if (Object.hasOwn(schema, 'const') && JSON.stringify(value) !== JSON.stringify(schema.const)) add('INVALID_FIELD_VALUE', `Expected ${JSON.stringify(schema.const)}.`);
  if (schema.enum && !schema.enum.some(option => JSON.stringify(value) === JSON.stringify(option))) add('INVALID_FIELD_VALUE', `Expected one of ${schema.enum.join(', ')}.`);
  if (typeof value === 'string') {
    if (schema.minLength && value.trim().length < schema.minLength) add('REQUIRED_FIELD_EMPTY', 'Required text is empty.');
    if (schema.pattern && !new RegExp(schema.pattern, 'u').test(value)) add('INVALID_FIELD_VALUE', `Does not match ${schema.pattern}.`);
  }
  if (typeof value === 'number') {
    if (schema.minimum !== undefined && value < schema.minimum) add('INVALID_FIELD_VALUE', `Must be >= ${schema.minimum}.`);
    if (schema.maximum !== undefined && value > schema.maximum) add('INVALID_FIELD_VALUE', `Must be <= ${schema.maximum}.`);
  }
  if (isObject(value)) {
    for (const key of schema.required ?? []) if (!Object.hasOwn(value, key)) add('REQUIRED_FIELD_MISSING', `Missing required field ${key}.`, `/${pointer(key)}`);
    for (const [key, child] of Object.entries(value)) {
      const childSchema = schema.properties?.[key];
      if (childSchema) errors.push(...validateSchema(child, childSchema, root, `${at}/${pointer(key)}`));
      else if (schema.additionalProperties === false) add('UNKNOWN_FIELD', `Unsupported field ${key}.`, `/${pointer(key)}`);
      else if (isObject(schema.additionalProperties)) errors.push(...validateSchema(child, schema.additionalProperties, root, `${at}/${pointer(key)}`));
    }
  }
  if (Array.isArray(value)) {
    if (schema.minItems && value.length < schema.minItems) add('REQUIRED_FIELD_EMPTY', `Expected at least ${schema.minItems} item(s).`);
    if (schema.uniqueItems && new Set(value.map(item => JSON.stringify(item))).size !== value.length) add('DUPLICATE_ITEM', 'Array entries must be unique.');
    if (schema.items) value.forEach((item, index) => errors.push(...validateSchema(item, schema.items, root, `${at}/${index}`)));
  }
  return errors;
}

export function parseShopifyJson(text) {
  // Shopify's generated templates have one leading block comment. Do not strip
  // // comments: doing that would corrupt URLs in strings.
  return JSON.parse(text.replace(/^\s*\/\*[\s\S]*?\*\/\s*/u, ''));
}
