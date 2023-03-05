/**
 * Checks, if value is an empty object
 * @param {*} value - the value to check
 * @returns {boolean} - returns true, if value is empty object, else false
 */
export const isEmptyObject = (value) => (
  !value ||
  JSON.stringify(value) === "{}" ||
  (
    Object.prototype.toString.call(
        value,
      ) === "[object Object]" && Object.keys(value).length < 1
  )
);
