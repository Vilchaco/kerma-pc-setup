// kermasetup.netlify.app/  ->  quien lo pide decide la respuesta:
//   - un navegador (pide text/html y no es PowerShell): la pagina de bienvenida (web/index.html)
//   - PowerShell, curl o cualquier otro: 302 al bootstrap.ps1 de main, como siempre,
//     para que `irm https://kermasetup.netlify.app | iex` siga funcionando.
import type { Context } from "https://edge.netlify.com";

const BOOTSTRAP = "https://raw.githubusercontent.com/Vilchaco/kerma-pc-setup/main/bootstrap.ps1";

export default async (req: Request, context: Context) => {
  const ua = req.headers.get("user-agent") || "";
  const accept = req.headers.get("accept") || "";
  const isPowerShell = /PowerShell/i.test(ua);
  const isBrowser = !isPowerShell && accept.includes("text/html");
  if (isBrowser) return context.next();
  return new Response(null, { status: 302, headers: { location: BOOTSTRAP, "cache-control": "no-store", vary: "User-Agent, Accept" } });
};

export const config = { path: "/" };
