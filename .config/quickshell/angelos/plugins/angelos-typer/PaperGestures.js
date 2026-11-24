.pragma library

function released(previous, x, y, time, moved, interval, distance) {
    if (moved) return {count: 0, time: 0, x: x, y: y, remove: false};
    const near = previous && Math.abs(x - previous.x) + Math.abs(y - previous.y) <= distance;
    const quick = previous && time >= previous.time && time - previous.time <= interval;
    const count = near && quick ? previous.count + 1 : 1;
    return {count: count >= 3 ? 0 : count, time: time, x: x, y: y, remove: count >= 3};
}

function dragPosition(origin, start, pointer, maximum) {
    return {
        x: Math.max(0, Math.min(maximum.x, origin.x + pointer.x - start.x)),
        y: Math.max(0, Math.min(maximum.y, origin.y + pointer.y - start.y))
    };
}
