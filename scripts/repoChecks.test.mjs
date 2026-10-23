// Plain Node checks that need no Salesforce org: sample data and metadata are consistent.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';

const root = new URL('../', import.meta.url);
const read = (p) => readFileSync(new URL(p, root), 'utf8');

test('sample loan picklist values exist in metadata', () => {
    const loans = JSON.parse(read('data/Loan_Application__c.json')).records;
    const fieldXml = (f) => read(`force-app/main/default/objects/Loan_Application__c/fields/${f}.field-meta.xml`);
    for (const [field, key] of [['Stage__c', 'Stage__c'], ['Product__c', 'Product__c'], ['Credit_Score_Band__c', 'Credit_Score_Band__c']]) {
        const xml = fieldXml(field);
        for (const loan of loans) {
            assert.ok(xml.includes(`<fullName>${loan[key]}</fullName>`), `${field} value ${loan[key]} missing`);
        }
    }
});

test('every Apex class has a meta file', () => {
    const dir = new URL('force-app/main/default/classes/', root);
    const files = readdirSync(dir);
    for (const f of files.filter((x) => x.endsWith('.cls'))) {
        assert.ok(files.includes(`${f}-meta.xml`), `${f} has no -meta.xml`);
    }
});
