# footage/

Drop raw video here — one subfolder per project.

```
footage/
  launch-video/
    take-01.mov
    take-02.mov
    screen-capture.mp4
  customer-story/
    interview.mp4
```

Then point the agent at the folder:

> edit footage/launch-video into a 90-second launch video

Everything the skill produces lands in an `edit/` subdirectory next to the
sources (`footage/launch-video/edit/final.mp4`), so the sources are never
modified in place.

Media files in here are gitignored — this directory is a working area, not
storage. Keep masters wherever LAMANO keeps masters.
