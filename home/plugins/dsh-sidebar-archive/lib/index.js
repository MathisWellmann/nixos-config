/**
 * dsh-sidebar-archive — host half.
 *
 * Deliberate no-op. The tree row this package carries needs a resolvable
 * host module (profile bundles insert the row into the composed config tree),
 * and the node half of the Web client module scanner reads this package's
 * `dsh.client` declaration to compose the browser boot graph from it. There
 * is no host-side capability behind the button: the browser half calls the
 * existing `workspace.archiveSession` RPC the sidebar's own row menu uses.
 */
export const name = "dsh-sidebar-archive";

/**
 * @param {import('@deepseek-ai/cordis').Context} _ctx
 */
export function apply(_ctx) {
  // Nothing to do on the host plane.
}
