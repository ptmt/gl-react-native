const {createShaders} = require("gl-react-core");
const { NativeModules: { RNGLContext } } = require("./React");

module.exports = createShaders(function (id, shader) {
  RNGLContext.addShader(id, shader);
});
