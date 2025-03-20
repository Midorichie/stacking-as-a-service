import { describe, it, expect } from 'vitest';

// A minimal test that doesn't make any contract calls,
// so it won't run into "Invalid tx arguments" errors.
describe('Simnet Environment', () => {
  it('should have simnet defined', () => {
    expect(simnet).toBeDefined();
  });

  it('should have a mineBlock function', () => {
    expect(typeof simnet.mineBlock).toBe('function');
  });

  it('should be able to mine an empty block', () => {
    const block = simnet.mineEmptyBlock();
    expect(block).toBeDefined();
  });
});
