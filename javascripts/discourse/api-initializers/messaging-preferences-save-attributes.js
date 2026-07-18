import { apiInitializer } from "discourse/lib/api";

// Messaging preferences are saved through the plugin endpoint by the early
// preferences/users controller extension. Keeping this initializer as a no-op
// avoids sending every serialized user custom field through the core save API.
export default apiInitializer(() => {
  // Intentionally empty.
});
