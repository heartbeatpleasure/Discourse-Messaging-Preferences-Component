import { apiInitializer } from "discourse/lib/api";

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
