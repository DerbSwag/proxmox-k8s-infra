import http from 'k6/http';
import { check, sleep } from 'k6';

// Ramp up to 100 VUs over 2 min, sustain 3 min, ramp down 1 min
export const options = {
  stages: [
    { duration: '2m', target: 100 },  // ramp up
    { duration: '3m', target: 100 },  // sustain
    { duration: '1m', target: 0 },    // ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],
  },
};

export default function () {
  const res = http.get('http://10.0.1.140:30627/');
  check(res, { 'status 200': (r) => r.status === 200 });
  sleep(0.1);
}
