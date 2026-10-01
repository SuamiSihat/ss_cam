// vite.config.mjs
import { defineConfig } from "file:///E:/Dev/Projects/SS-Brand-Assets/src/SS-CAM.Web/node_modules/vite/dist/node/index.js";
import { svelte } from "file:///E:/Dev/Projects/SS-Brand-Assets/src/SS-CAM.Web/node_modules/@sveltejs/vite-plugin-svelte/src/index.js";
import path from "path";
import { fileURLToPath } from "url";
var __vite_injected_original_import_meta_url = "file:///E:/Dev/Projects/SS-Brand-Assets/src/SS-CAM.Web/vite.config.mjs";
var __filename = fileURLToPath(__vite_injected_original_import_meta_url);
var __dirname = path.dirname(__filename);
var vite_config_default = defineConfig({
  plugins: [svelte()],
  root: "client",
  publicDir: "public",
  resolve: {
    alias: {
      "$lib": path.resolve(__dirname, "client/src/lib")
    }
  },
  build: {
    outDir: "dist",
    emptyOutDir: true,
    target: "es2022",
    chunkSizeWarningLimit: 3500,
    rollupOptions: {
      output: {
        manualChunks: (id) => {
          const normalized = id.replace(/\\/g, "/");
          if (normalized.includes("/node_modules/katex/")) {
            return "vendor-katex";
          }
          if (normalized.includes("/node_modules/marked/") || normalized.includes("/node_modules/dompurify/")) {
            return "vendor-markdown";
          }
          if (normalized.includes("/node_modules/svelte/") || normalized.includes("/node_modules/@sveltejs/")) {
            return "vendor-svelte";
          }
        }
      }
    }
  },
  server: {
    port: 5173,
    proxy: {
      "/api": {
        target: "http://localhost:4000",
        changeOrigin: true
      }
    }
  }
});
export {
  vite_config_default as default
};
//# sourceMappingURL=data:application/json;base64,ewogICJ2ZXJzaW9uIjogMywKICAic291cmNlcyI6IFsidml0ZS5jb25maWcubWpzIl0sCiAgInNvdXJjZXNDb250ZW50IjogWyJjb25zdCBfX3ZpdGVfaW5qZWN0ZWRfb3JpZ2luYWxfZGlybmFtZSA9IFwiRTpcXFxcRGV2XFxcXFByb2plY3RzXFxcXFNTLUJyYW5kLUFzc2V0c1xcXFxzcmNcXFxcU1MtQ0FNLldlYlwiO2NvbnN0IF9fdml0ZV9pbmplY3RlZF9vcmlnaW5hbF9maWxlbmFtZSA9IFwiRTpcXFxcRGV2XFxcXFByb2plY3RzXFxcXFNTLUJyYW5kLUFzc2V0c1xcXFxzcmNcXFxcU1MtQ0FNLldlYlxcXFx2aXRlLmNvbmZpZy5tanNcIjtjb25zdCBfX3ZpdGVfaW5qZWN0ZWRfb3JpZ2luYWxfaW1wb3J0X21ldGFfdXJsID0gXCJmaWxlOi8vL0U6L0Rldi9Qcm9qZWN0cy9TUy1CcmFuZC1Bc3NldHMvc3JjL1NTLUNBTS5XZWIvdml0ZS5jb25maWcubWpzXCI7aW1wb3J0IHsgZGVmaW5lQ29uZmlnIH0gZnJvbSAndml0ZSc7XHJcbmltcG9ydCB7IHN2ZWx0ZSB9IGZyb20gJ0BzdmVsdGVqcy92aXRlLXBsdWdpbi1zdmVsdGUnO1xyXG5pbXBvcnQgcGF0aCBmcm9tICdwYXRoJztcclxuaW1wb3J0IHsgZmlsZVVSTFRvUGF0aCB9IGZyb20gJ3VybCc7XHJcblxyXG5jb25zdCBfX2ZpbGVuYW1lID0gZmlsZVVSTFRvUGF0aChpbXBvcnQubWV0YS51cmwpO1xyXG5jb25zdCBfX2Rpcm5hbWUgPSBwYXRoLmRpcm5hbWUoX19maWxlbmFtZSk7XHJcblxyXG4vLyBodHRwczovL3ZpdGVqcy5kZXYvY29uZmlnL1xyXG5leHBvcnQgZGVmYXVsdCBkZWZpbmVDb25maWcoe1xyXG4gIHBsdWdpbnM6IFtzdmVsdGUoKV0sXHJcbiAgcm9vdDogJ2NsaWVudCcsXHJcbiAgcHVibGljRGlyOiAncHVibGljJyxcclxuICByZXNvbHZlOiB7XHJcbiAgICBhbGlhczoge1xyXG4gICAgICAnJGxpYic6IHBhdGgucmVzb2x2ZShfX2Rpcm5hbWUsICdjbGllbnQvc3JjL2xpYicpXHJcbiAgICB9XHJcbiAgfSxcclxuICBidWlsZDoge1xyXG4gICAgb3V0RGlyOiAnZGlzdCcsXHJcbiAgICBlbXB0eU91dERpcjogdHJ1ZSxcclxuICAgIHRhcmdldDogJ2VzMjAyMicsXHJcbiAgICBjaHVua1NpemVXYXJuaW5nTGltaXQ6IDM1MDAsXHJcbiAgICByb2xsdXBPcHRpb25zOiB7XHJcbiAgICAgIG91dHB1dDoge1xyXG4gICAgICAgIG1hbnVhbENodW5rczogKGlkKSA9PiB7XHJcbiAgICAgICAgICBjb25zdCBub3JtYWxpemVkID0gaWQucmVwbGFjZSgvXFxcXC9nLCAnLycpO1xyXG4gICAgICAgICAgLy8gTk9URTogbWVybWFpZCBpcyBpbnRlbnRpb25hbGx5IE5PVCBsaXN0ZWQgaGVyZS5cclxuICAgICAgICAgIC8vIEl0IGlzIGxhemlseSBpbXBvcnRlZCB2aWEgTWFya2Rvd25WaWV3ZXIuJGVmZmVjdCBcdTIxOTIgaW1wb3J0KCcuL01lcm1haWRWaWV3ZXIuc3ZlbHRlJylcclxuICAgICAgICAgIC8vIExpc3RpbmcgaXQgaW4gbWFudWFsQ2h1bmtzIHdvdWxkIGZvcmNlIFJvbGx1cCB0byBhZGQgaXQgdG8gbW9kdWxlcHJlbG9hZCxcclxuICAgICAgICAgIC8vIGxvYWRpbmcgM01CIG9uIGV2ZXJ5IHBhZ2UgdmlzaXQuIExlYXZlIGl0IGFzIGEgcHVyZSBhc3luYyBjaHVuay5cclxuICAgICAgICAgIGlmIChub3JtYWxpemVkLmluY2x1ZGVzKCcvbm9kZV9tb2R1bGVzL2thdGV4LycpKSB7XHJcbiAgICAgICAgICAgIHJldHVybiAndmVuZG9yLWthdGV4JzsgLy8ga2F0ZXggaXMgbWVybWFpZCdzIGRlcCwga2VlcCBpdCBpbiBpdHMgb3duIGFzeW5jIGNodW5rXHJcbiAgICAgICAgICB9XHJcbiAgICAgICAgICBpZiAobm9ybWFsaXplZC5pbmNsdWRlcygnL25vZGVfbW9kdWxlcy9tYXJrZWQvJykgfHwgbm9ybWFsaXplZC5pbmNsdWRlcygnL25vZGVfbW9kdWxlcy9kb21wdXJpZnkvJykpIHtcclxuICAgICAgICAgICAgcmV0dXJuICd2ZW5kb3ItbWFya2Rvd24nO1xyXG4gICAgICAgICAgfVxyXG4gICAgICAgICAgaWYgKG5vcm1hbGl6ZWQuaW5jbHVkZXMoJy9ub2RlX21vZHVsZXMvc3ZlbHRlLycpIHx8IG5vcm1hbGl6ZWQuaW5jbHVkZXMoJy9ub2RlX21vZHVsZXMvQHN2ZWx0ZWpzLycpKSB7XHJcbiAgICAgICAgICAgIHJldHVybiAndmVuZG9yLXN2ZWx0ZSc7XHJcbiAgICAgICAgICB9XHJcbiAgICAgICAgfVxyXG4gICAgICB9XHJcbiAgICB9XHJcbiAgfSxcclxuICBzZXJ2ZXI6IHtcclxuICAgIHBvcnQ6IDUxNzMsXHJcbiAgICBwcm94eToge1xyXG4gICAgICAnL2FwaSc6IHtcclxuICAgICAgICB0YXJnZXQ6ICdodHRwOi8vbG9jYWxob3N0OjQwMDAnLFxyXG4gICAgICAgIGNoYW5nZU9yaWdpbjogdHJ1ZVxyXG4gICAgICB9XHJcbiAgICB9XHJcbiAgfVxyXG59KTtcclxuIl0sCiAgIm1hcHBpbmdzIjogIjtBQUEwVSxTQUFTLG9CQUFvQjtBQUN2VyxTQUFTLGNBQWM7QUFDdkIsT0FBTyxVQUFVO0FBQ2pCLFNBQVMscUJBQXFCO0FBSGtMLElBQU0sMkNBQTJDO0FBS2pRLElBQU0sYUFBYSxjQUFjLHdDQUFlO0FBQ2hELElBQU0sWUFBWSxLQUFLLFFBQVEsVUFBVTtBQUd6QyxJQUFPLHNCQUFRLGFBQWE7QUFBQSxFQUMxQixTQUFTLENBQUMsT0FBTyxDQUFDO0FBQUEsRUFDbEIsTUFBTTtBQUFBLEVBQ04sV0FBVztBQUFBLEVBQ1gsU0FBUztBQUFBLElBQ1AsT0FBTztBQUFBLE1BQ0wsUUFBUSxLQUFLLFFBQVEsV0FBVyxnQkFBZ0I7QUFBQSxJQUNsRDtBQUFBLEVBQ0Y7QUFBQSxFQUNBLE9BQU87QUFBQSxJQUNMLFFBQVE7QUFBQSxJQUNSLGFBQWE7QUFBQSxJQUNiLFFBQVE7QUFBQSxJQUNSLHVCQUF1QjtBQUFBLElBQ3ZCLGVBQWU7QUFBQSxNQUNiLFFBQVE7QUFBQSxRQUNOLGNBQWMsQ0FBQyxPQUFPO0FBQ3BCLGdCQUFNLGFBQWEsR0FBRyxRQUFRLE9BQU8sR0FBRztBQUt4QyxjQUFJLFdBQVcsU0FBUyxzQkFBc0IsR0FBRztBQUMvQyxtQkFBTztBQUFBLFVBQ1Q7QUFDQSxjQUFJLFdBQVcsU0FBUyx1QkFBdUIsS0FBSyxXQUFXLFNBQVMsMEJBQTBCLEdBQUc7QUFDbkcsbUJBQU87QUFBQSxVQUNUO0FBQ0EsY0FBSSxXQUFXLFNBQVMsdUJBQXVCLEtBQUssV0FBVyxTQUFTLDBCQUEwQixHQUFHO0FBQ25HLG1CQUFPO0FBQUEsVUFDVDtBQUFBLFFBQ0Y7QUFBQSxNQUNGO0FBQUEsSUFDRjtBQUFBLEVBQ0Y7QUFBQSxFQUNBLFFBQVE7QUFBQSxJQUNOLE1BQU07QUFBQSxJQUNOLE9BQU87QUFBQSxNQUNMLFFBQVE7QUFBQSxRQUNOLFFBQVE7QUFBQSxRQUNSLGNBQWM7QUFBQSxNQUNoQjtBQUFBLElBQ0Y7QUFBQSxFQUNGO0FBQ0YsQ0FBQzsiLAogICJuYW1lcyI6IFtdCn0K
