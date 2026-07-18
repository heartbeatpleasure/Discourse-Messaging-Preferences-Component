import { apiInitializer } from "discourse/lib/api";

// Keep the plugin-owned custom fields compatible with Discourse's normal
// Users preferences save flow, but do not depend on overriding the controller.
export default apiInitializer((api) => {
  api.registerValueTransformer(
    "preferences-save-attributes",
    ({ value: attributes, context }) => {
      if (context.page !== "users" || attributes.includes("custom_fields")) {
        return attributes;
      }

      return [...attributes, "custom_fields"];
    }
  );
});
