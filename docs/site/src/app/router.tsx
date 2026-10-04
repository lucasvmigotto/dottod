import { HashRouter, Route, Routes, useParams } from "react-router-dom";
import { Layout } from "../components/chrome";
import { GUIDE_IDS, type PageId, TASK_IDS } from "../i18n/types";
import { DocPageView, NotFound } from "../pages/DocPage";

// HashRouter: the static host has no SPA fallback, so hash routing keeps
// deep links working. The docs-hub prefix (/dottod/) lives in the URL
// pathname via Vite's `base`; the hash carries the route on its own.
// A hash router must NOT also set `basename`: React Router would look for
// the prefix inside the hash, match nothing, and render a blank page.
const NEXT: Partial<Record<PageId, PageId>> = {
  overview: "start",
  start: "tasks",
  tasks: "task-shell",
};

for (let i = 0; i < TASK_IDS.length - 1; i++) {
  NEXT[`task-${TASK_IDS[i]}` as PageId] = `task-${TASK_IDS[i + 1]}` as PageId;
}
NEXT[`task-${TASK_IDS[TASK_IDS.length - 1]}` as PageId] = "commands";

export function Router() {
  return (
    <HashRouter>
      <Layout>
        <Routes>
          <Route
            path="/"
            element={<DocPageView pageId="overview" next={NEXT.overview} />}
          />
          <Route
            path="/start"
            element={<DocPageView pageId="start" next={NEXT.start} />}
          />
          <Route
            path="/tasks"
            element={<DocPageView pageId="tasks" next={NEXT.tasks} />}
          />
          {TASK_IDS.map((t) => {
            const id = `task-${t}` as PageId;
            return (
              <Route
                key={id}
                path={`/tasks/${t}`}
                element={<DocPageView pageId={id} next={NEXT[id]} />}
              />
            );
          })}
          <Route path="/guides/:guide" element={<GuideRoute />} />
          <Route
            path="/commands"
            element={<DocPageView pageId="commands" next="config" />}
          />
          <Route
            path="/config"
            element={<DocPageView pageId="config" next="concepts" />}
          />
          <Route
            path="/concepts"
            element={<DocPageView pageId="concepts" next="architecture" />}
          />
          <Route
            path="/architecture"
            element={<DocPageView pageId="architecture" next="roadmap" />}
          />
          <Route path="/roadmap" element={<DocPageView pageId="roadmap" />} />
          <Route path="*" element={<NotFound />} />
        </Routes>
      </Layout>
    </HashRouter>
  );
}

function GuideRoute() {
  const { guide } = useParams();
  const id = `guide-${guide}` as PageId;
  if (!(GUIDE_IDS as readonly string[]).includes(guide ?? ""))
    return <NotFound />;
  return <DocPageView pageId={id} />;
}
